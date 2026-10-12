import express from "express";
import { z } from "zod";
import { ApiError, clientKey, handle, parse, RateGate, requireUser, TtlCache, type Authenticate } from "./api-helpers.js";
import type { Clip } from "./clips.js";
import type { MusicGraph } from "./graph.js";
import type { ProviderAccess, ProviderTrack } from "./provider-gateway.js";
import { releaseTime, type Release } from "./releases.js";
import type { SetlistService } from "./setlists.js";
import type { SocialStore } from "./social-store.js";
import { normalize, type WaveProviderName } from "./wave.js";

export type Concert = {
  id: string;
  date: string;
  venue: string | null;
  city: string | null;
  country: string | null;
  url: string | null;
};

export interface ConcertSource {
  readonly available: boolean;
  upcoming(artist: string): Promise<Concert[]>;
}

/** Bandsintown events (optional: BANDSINTOWN_APP_ID). Disabled → always empty. */
export class BandsintownConcerts implements ConcertSource {
  readonly #cache: TtlCache<Concert[]>;
  constructor(private readonly appId = "", private readonly request: typeof fetch = fetch) {
    this.#cache = new TtlCache(6 * 60 * 60_000, 1_000);
  }

  static fromEnvironment(env = process.env) {
    return new BandsintownConcerts(env.BANDSINTOWN_APP_ID?.trim() || "");
  }

  get available() { return Boolean(this.appId); }

  async upcoming(artist: string): Promise<Concert[]> {
    if (!this.available) return [];
    return this.#cache.get(normalize(artist), async () => {
      const url = new URL(`https://rest.bandsintown.com/artists/${encodeURIComponent(artist.trim())}/events`);
      url.searchParams.set("app_id", this.appId);
      const response = await this.request(url, { headers: { accept: "application/json" }, signal: AbortSignal.timeout(8_000) }).catch(() => undefined);
      if (!response?.ok) return [];
      const data = await response.json().catch(() => []) as unknown;
      return (Array.isArray(data) ? data : []).slice(0, 20).flatMap((raw) => {
        const event = raw as Record<string, any>;
        if (event.id === undefined || typeof event.datetime !== "string") return [];
        return [{
          id: String(event.id),
          date: event.datetime,
          venue: event.venue?.name ? String(event.venue.name) : null,
          city: event.venue?.city ? String(event.venue.city) : null,
          country: event.venue?.country ? String(event.venue.country) : null,
          url: typeof event.url === "string" && event.url.startsWith("https://") ? event.url : null
        }];
      });
    });
  }
}

type Search = (provider: WaveProviderName, query: string, limit: number, access?: ProviderAccess) => Promise<ProviderTrack[]>;

export interface ArtistPageDeps {
  search: Search;
  releases: { available: boolean; feed(artists: string[], days?: number): Promise<{ available: boolean; releases: Release[] }> };
  clips?: { find(title: string, artist: string): Promise<Clip[]> };
  concerts?: ConcertSource;
  setlists?: SetlistService;
  graph?: MusicGraph;
  social: SocialStore;
}

const settle = async <T>(task: Promise<T>, fallback: T) => {
  try { return await task; } catch { return fallback; }
};

/** «Страница артиста 2.0»: one aggregated request instead of five from the client. */
export class ArtistPageService {
  constructor(private readonly deps: ArtistPageDeps) {}

  async overview(artist: string, options: { userId?: string; provider: WaveProviderName; access?: ProviderAccess }) {
    const name = artist.trim();
    const key = normalize(name);
    const topTracks = await settle(this.deps.search(options.provider, name, 15, options.access), [] as ProviderTrack[]);
    const own = topTracks.filter((track) => normalize(track.artist).includes(key)).slice(0, 10);
    const [releases, clips, concerts, setlists, similar] = await Promise.all([
      settle(this.deps.releases.feed([name], 365), { available: this.deps.releases.available, releases: [] as Release[] }),
      this.#clips(name, own),
      settle(this.deps.concerts?.upcoming(name) ?? Promise.resolve([]), [] as Concert[]),
      settle(this.deps.setlists?.recent(name, 3) ?? Promise.resolve({ available: false, setlists: [] }), { available: false, setlists: [] }),
      settle(this.deps.graph?.neighbors(name, { limit: 10 }).then((result) => result.neighbors) ?? Promise.resolve([]), [])
    ]);
    return {
      artist: name,
      provider: options.provider,
      topTracks: own.map((track) => ({ ...track, provider: options.provider })),
      releases: { available: releases.available, items: releases.releases.slice(0, 20) },
      clips,
      concerts: { available: this.deps.concerts?.available ?? false, items: concerts },
      setlists,
      similar,
      following: options.userId ? this.deps.social.isFollowing(options.userId, name) : false
    };
  }

  async #clips(artist: string, tracks: ProviderTrack[]) {
    if (!this.deps.clips) return [];
    const found = await Promise.all(tracks.slice(0, 3).map((track) => settle(this.deps.clips!.find(track.title, artist), [] as Clip[])));
    const seen = new Set<string>();
    return found.flat().filter((clip) => {
      const id = String((clip as { id?: unknown }).id ?? JSON.stringify(clip));
      if (seen.has(id)) return false;
      seen.add(id);
      return true;
    }).slice(0, 6);
  }

  /** New releases of followed artists published after the last «seen» mark (push/badge source). */
  async unread(userId: string) {
    const follows = this.deps.social.follows(userId);
    if (!follows.length || !this.deps.releases.available) {
      return { available: this.deps.releases.available, count: 0, releases: [] as Array<Release & { followedArtist: string }> };
    }
    const feed = await this.deps.releases.feed(follows.map((follow) => follow.artist), 60);
    const seen = this.deps.social.seenReleaseIds(userId);
    const releases = feed.releases.flatMap((release) => {
      const artist = normalize(release.artist);
      const follow = follows.find((entry) => artist.includes(entry.key));
      if (!follow || seen.has(release.id)) return [];
      // Only releases dated on or after the day the artist was followed count as new.
      const followedDay = Math.floor(Date.parse(follow.followedAt) / 86_400_000) * 86_400_000;
      if (releaseTime(release.releaseDate) < followedDay) return [];
      return [{ ...release, followedArtist: follow.artist }];
    });
    return { available: feed.available, count: releases.length, releases };
  }

  /** Marks the current unread releases (of one artist or all) as read. */
  async markSeen(userId: string, artist?: string) {
    const { releases } = await this.unread(userId);
    const key = artist ? normalize(artist) : undefined;
    const ids = releases.filter((release) => !key || normalize(release.followedArtist) === key).map((release) => release.id);
    this.deps.social.markReleasesSeen(userId, ids, artist);
    return ids.length;
  }
}

const artistSchema = z.string().trim().min(1).max(200);

export function createArtistRouter(
  service: ArtistPageService,
  social: SocialStore,
  authenticate: Authenticate,
  access: (request: express.Request) => Partial<Record<WaveProviderName, ProviderAccess>> = () => ({})
) {
  const router = express.Router();
  const gate = new RateGate(60, 60_000);
  router.use((request, response, next) => {
    response.setHeader("cache-control", "private, no-store");
    try {
      gate.check(clientKey(request));
      next();
    } catch (error) {
      handle(() => { throw error; })(request, response);
    }
  });

  router.get("/overview", handle(async (request) => {
    const query = parse(z.object({
      name: artistSchema,
      provider: z.enum(["soundcloud", "yandex", "spotify", "vk"]).default("soundcloud")
    }), request.query, "Укажите артиста");
    return service.overview(query.name, {
      userId: authenticate(request),
      provider: query.provider,
      access: access(request)[query.provider]
    });
  }));

  router.get("/follows", handle((request) => ({ follows: social.follows(requireUser(authenticate, request)) })));
  router.put("/follows", handle((request) => {
    const userId = requireUser(authenticate, request);
    const { artist } = parse(z.object({ artist: artistSchema }).strict(), request.body, "Укажите артиста");
    return { follow: social.follow(userId, artist) };
  }));
  router.delete("/follows", handle((request, response) => {
    const userId = requireUser(authenticate, request);
    const artist = parse(artistSchema, request.query.artist ?? request.body?.artist, "Укажите артиста");
    social.unfollow(userId, artist);
    response.status(204).end();
  }));
  router.get("/releases/unread", handle((request) => service.unread(requireUser(authenticate, request))));
  router.post("/releases/seen", handle(async (request) => {
    const userId = requireUser(authenticate, request);
    const body = parse(z.object({ artist: artistSchema.optional() }).strict(), request.body ?? {});
    if (body.artist && !social.isFollowing(userId, body.artist)) throw new ApiError("NOT_FOLLOWING", "Вы не следите за этим артистом", 404);
    return { marked: await service.markSeen(userId, body.artist) };
  }));
  return router;
}
