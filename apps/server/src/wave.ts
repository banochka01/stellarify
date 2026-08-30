import { randomUUID } from "node:crypto";
import type { ProviderAccess, ProviderTrack } from "./provider-gateway.js";
import { ProviderGateway } from "./provider-gateway.js";
import { YandexAdapter } from "./yandex.js";

export type WaveProviderName = "soundcloud" | "yandex" | "youtube";
export type WaveAccess = Partial<Record<WaveProviderName, ProviderAccess>>;
export type WaveFeedbackType = "started" | "finished" | "skipped" | "liked" | "disliked";

export interface WaveRequest {
  seedQueries: string[];
  enabledProviders: WaveProviderName[];
  discovery: number;
  mood: "fun" | "active" | "calm" | "sad" | "all";
  language: "not-russian" | "russian" | "any";
}

export interface WaveItem extends ProviderTrack {
  provider: WaveProviderName;
  batchId?: string;
  score: number;
  lane: "safe" | "adjacent" | "wild";
}

interface WaveSession {
  id: string;
  request: WaveRequest;
  station?: string;
  batchId?: string;
  queue?: string;
  recentTracks: string[];
  recentArtists: string[];
  recentAlbums: string[];
  feedbackIds: Set<string>;
  expiresAt: number;
}

export class WaveService {
  private readonly sessions = new Map<string, WaveSession>();

  constructor(
    private readonly gateway: ProviderGateway,
    private readonly yandex: YandexAdapter,
    private readonly now: () => number = Date.now
  ) {}

  async start(request: WaveRequest, access: WaveAccess = {}) {
    this.sweep();
    const session: WaveSession = {
      id: randomUUID(),
      request,
      recentTracks: [],
      recentArtists: [],
      recentAlbums: [],
      feedbackIds: new Set(),
      expiresAt: this.now() + 30 * 60_000
    };
    this.sessions.set(session.id, session);
    const items = await this.fill(session, access);
    return this.response(session, items);
  }

  async next(id: string, access: WaveAccess = {}) {
    const session = this.requireSession(id);
    const items = await this.fill(session, access);
    return this.response(session, items);
  }

  async feedback(
    id: string,
    event: {
      eventId: string;
      type: WaveFeedbackType;
      trackId: string;
      provider: WaveProviderName;
      batchId?: string;
      playedDurationMs: number;
    },
    access: WaveAccess = {}
  ) {
    const session = this.requireSession(id);
    if (session.feedbackIds.has(event.eventId)) return { accepted: true, duplicate: true };
    session.feedbackIds.add(event.eventId);
    if (session.feedbackIds.size > 500) {
      const first = session.feedbackIds.values().next().value;
      if (first) session.feedbackIds.delete(first);
    }
    session.expiresAt = this.now() + 30 * 60_000;
    if (event.provider === "yandex" && session.station && ["started", "finished", "skipped"].includes(event.type)) {
      const rotorType = event.type === "started" ? "trackStarted" : event.type === "finished" ? "trackFinished" : "skip";
      await this.yandex.waveFeedback(session.station, rotorType, {
        trackId: event.trackId,
        batchId: event.batchId || session.batchId,
        totalPlayedSeconds: Math.max(0, Math.round(event.playedDurationMs / 1000))
      }, access.yandex);
    }
    return { accepted: true, duplicate: false };
  }

  stop(id: string) {
    return this.sessions.delete(id);
  }

  private async fill(session: WaveSession, access: WaveAccess) {
    const candidates: WaveItem[] = [];
    if (session.request.enabledProviders.includes("yandex")) {
      try {
        const diversity = session.request.discovery >= .67 ? "discover" : session.request.discovery <= .33 ? "favorite" : "default";
        const batch = await this.yandex.waveBatch({
          mood: session.request.mood,
          diversity,
          language: session.request.language,
          station: session.station,
          queue: session.queue
        }, access.yandex);
        session.station = batch.station;
        session.batchId = batch.batchId;
        for (const track of batch.tracks) candidates.push(this.item("yandex", track, "safe", .95, batch.batchId));
      } catch {
        // A missing/expired Yandex token must not prevent the native fallback.
      }
    }

    const configuredSeeds = session.request.seedQueries.length
      ? session.request.seedQueries
      : ["новинки музыки"];
    const continuationSeeds = session.recentTracks.length
      ? [...new Set([...session.recentArtists].reverse())]
      : [];
    const seeds = [...new Set([...continuationSeeds, ...configuredSeeds])].slice(0, 5);
    const providers = session.request.enabledProviders;
    const searches = providers.flatMap((provider) => seeds.slice(0, 3).map(async (query, index) => {
      try {
        const tracks = await this.gateway.search(
          provider,
          query,
          8,
          access[provider]
        );
        const lane = index === 0 ? "adjacent" as const : "wild" as const;
        return tracks.map((track, rank) => this.item(provider, track, lane, .76 - rank * .025));
      } catch {
        return [];
      }
    }));
    for (const result of await Promise.all(searches)) candidates.push(...result);
    // YouTube is an official visible-player source in Resonance, so it cannot be
    // inserted into a native background queue. Use its catalog as a discovery
    // signal and resolve those artists back through native-capable providers.
    const youtubeSeeds = [...new Set(candidates
      .filter((item) => item.provider === "youtube")
      .map((item) => item.artist.trim())
      .filter(Boolean))].slice(0, 3);
    const nativeProviders = providers.filter((provider) => provider !== "youtube");
    const expansions = nativeProviders.flatMap((provider) => youtubeSeeds.map(async (query) => {
      try {
        const tracks = await this.gateway.search(
          provider,
          query,
          5,
          access[provider]
        );
        return tracks.map((track, rank) => this.item(provider, track, "wild", .69 - rank * .025));
      } catch {
        return [];
      }
    }));
    for (const result of await Promise.all(expansions)) candidates.push(...result);
    const nativeCandidates = candidates.filter((item) => item.provider !== "youtube");
    const items = rerank(nativeCandidates, session, 20, session.request.discovery);
    for (const item of items) {
      session.recentTracks.push(trackKey(item));
      session.recentArtists.push(normalize(item.artist));
      if (item.album) session.recentAlbums.push(normalize(item.album));
    }
    session.recentTracks = session.recentTracks.slice(-100);
    session.recentArtists = session.recentArtists.slice(-10);
    session.recentAlbums = session.recentAlbums.slice(-5);
    const lastYandex = [...items].reverse().find((item) => item.provider === "yandex");
    if (lastYandex) session.queue = lastYandex.id;
    return items;
  }

  private item(provider: WaveProviderName, track: ProviderTrack, lane: WaveItem["lane"], base: number, batchId?: string): WaveItem {
    return { ...track, provider, lane, batchId, score: base };
  }

  private response(session: WaveSession, items: WaveItem[]) {
    session.expiresAt = this.now() + 30 * 60_000;
    return { sessionId: session.id, items, expiresAt: new Date(session.expiresAt).toISOString() };
  }

  private requireSession(id: string) {
    this.sweep();
    const session = this.sessions.get(id);
    if (!session) throw new WaveSessionError();
    return session;
  }

  private sweep() {
    const now = this.now();
    for (const [id, session] of this.sessions) if (session.expiresAt <= now) this.sessions.delete(id);
  }
}

export class WaveSessionError extends Error {}

export function rerank(candidates: WaveItem[], history: Pick<WaveSession, "recentTracks" | "recentArtists" | "recentAlbums">, limit: number, discovery: number) {
  const unique = new Map<string, WaveItem>();
  for (const candidate of candidates) {
    const key = trackKey(candidate);
    const old = unique.get(key);
    const providerBonus = candidate.provider === "youtube" ? .01 : candidate.provider === "soundcloud" ? .02 : 0;
    const discoveryBonus = candidate.lane === "wild" ? discovery * .12 : candidate.lane === "safe" ? (1 - discovery) * .12 : .06;
    const scored = { ...candidate, score: candidate.score + providerBonus + discoveryBonus };
    if (!old || scored.score > old.score) unique.set(key, scored);
  }
  const pending = [...unique.values()].sort((a, b) => b.score - a.score);
  const result: WaveItem[] = [];
  const artists = [...history.recentArtists];
  const albums = [...history.recentAlbums];
  const tracks = new Set(history.recentTracks);
  while (pending.length && result.length < limit) {
    let index = pending.findIndex((item) => {
      const artist = normalize(item.artist);
      const album = item.album && normalize(item.album);
      return !tracks.has(trackKey(item)) && artists.slice(-10).filter((value) => value === artist).length < 2 && (!album || !albums.slice(-5).includes(album));
    });
    if (index < 0) index = pending.findIndex((item) => {
      const artist = normalize(item.artist);
      return !tracks.has(trackKey(item)) && artists.slice(-10).filter((value) => value === artist).length < 2;
    });
    if (index < 0) break;
    const item = pending.splice(index, 1)[0];
    if (!item) break;
    result.push(item);
    tracks.add(trackKey(item));
    artists.push(normalize(item.artist));
    if (item.album) albums.push(normalize(item.album));
  }
  return result;
}

function trackKey(track: ProviderTrack) {
  return `${normalize(track.artist)}::${normalize(track.title)}`;
}

function normalize(value: string) {
  return value.toLocaleLowerCase("ru").replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}
