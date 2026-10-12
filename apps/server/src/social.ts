import express from "express";
import { z } from "zod";
import type { WaveBlock, WaveTasteSignals } from "./account-store.js";
import { ApiError, handle, parse, RateGate, requireUser, type Authenticate } from "./api-helpers.js";
import type { DailyMixesResult, DailyMixInput } from "./daily-mixes.js";
import type { LiveRoomPresence } from "./rooms.js";
import { publicProfile, type SocialStore } from "./social-store.js";
import { splitArtists } from "./track-matcher.js";
import type { WaveAccess, WaveProviderName } from "./wave.js";

/** Account data the social layer reads; implemented by AccountStore in production. */
export interface TasteSource {
  getWaveTasteSignals(userId: string): WaveTasteSignals;
  getWaveBlocks(userId: string): WaveBlock[];
}

export interface BlendBuilder {
  build(owner: string, input: DailyMixInput, access?: WaveAccess): Promise<DailyMixesResult>;
}

export type RoomPresenceSource = {
  live(userIds: string[]): LiveRoomPresence[];
  isMember(code: string, userId: string): boolean;
};

export type ArtistWeights = Map<string, { name: string; weight: number }>;

const signalWeight: Record<string, number> = { started: 1, finished: 2, liked: 3, skipped: 0, disliked: -2 };

/** Artist preference vector from history, favorites and playlists; keys are normalized artist names. */
export function artistWeights(signals: WaveTasteSignals): ArtistWeights {
  const weights: ArtistWeights = new Map();
  const add = (artist: string, weight: number) => {
    for (const [index, key] of splitArtists(artist).entries()) {
      if (!key) continue;
      const share = index === 0 ? weight : weight / 2;
      const entry = weights.get(key) ?? { name: index === 0 ? artist.trim() : key, weight: 0 };
      entry.weight += share;
      weights.set(key, entry);
    }
  };
  for (const item of signals.listening) add(item.artist, signalWeight[item.type] ?? 0);
  for (const item of signals.favorites) add(item.artist, 3);
  for (const item of signals.playlistTracks) add(item.artist, 1);
  for (const [key, entry] of weights) if (entry.weight <= 0) weights.delete(key);
  return weights;
}

export type Compatibility = {
  percent: number;
  enoughData: boolean;
  sharedArtists: string[];
  /** Genres are not tracked by providers in history yet: always empty for now. */
  sharedGenres: string[];
};

/**
 * Taste compatibility 0–100: a blend of cosine similarity of weighted artist
 * vectors (how similar the proportions are) and the overlap coefficient
 * (how much of the smaller library is shared).
 */
export function compatibility(left: ArtistWeights, right: ArtistWeights): Compatibility {
  let dot = 0;
  let leftNorm = 0;
  let rightNorm = 0;
  const shared: Array<{ name: string; weight: number }> = [];
  for (const [key, entry] of left) {
    leftNorm += entry.weight ** 2;
    const other = right.get(key);
    if (other) {
      dot += entry.weight * other.weight;
      shared.push({ name: entry.name, weight: Math.min(entry.weight, other.weight) });
    }
  }
  for (const entry of right.values()) rightNorm += entry.weight ** 2;
  const enoughData = left.size >= 3 && right.size >= 3;
  if (!leftNorm || !rightNorm) return { percent: 0, enoughData, sharedArtists: [], sharedGenres: [] };
  const cosine = dot / Math.sqrt(leftNorm * rightNorm);
  const overlap = shared.length / Math.min(left.size, right.size);
  const percent = Math.round(Math.min(1, 0.6 * cosine + 0.4 * overlap) * 100);
  return {
    percent,
    enoughData,
    sharedArtists: shared.sort((a, b) => b.weight - a.weight).slice(0, 10).map((entry) => entry.name),
    sharedGenres: []
  };
}

const topArtists = (weights: ArtistWeights, limit: number) =>
  [...weights.values()].sort((a, b) => b.weight - a.weight).slice(0, limit).map((entry) => entry.name);

type NowPlaying = { title: string; artist: string; provider?: string; trackId?: string; at: number };

const NOW_PLAYING_TTL = 10 * 60_000;
const RECENT_WINDOW = 3 * 24 * 60 * 60_000;

export class SocialService {
  readonly #nowPlaying = new Map<string, NowPlaying>();

  constructor(
    readonly store: SocialStore,
    private readonly taste: TasteSource,
    private readonly mixes: BlendBuilder,
    private readonly rooms: RoomPresenceSource,
    private readonly now: () => number = Date.now
  ) {}

  setNowPlaying(userId: string, track: Omit<NowPlaying, "at"> | null) {
    if (!track) this.#nowPlaying.delete(userId);
    else {
      if (this.#nowPlaying.size >= 50_000) this.#sweep();
      this.#nowPlaying.set(userId, { ...track, at: this.now() });
    }
  }

  /** «Что слушают друзья»: only friends who opted in to sharing listening and/or rooms. */
  feed(userId: string) {
    const friends = this.store.friendIds(userId).slice(0, 300).map((id) => this.store.profile(id));
    const listening = friends.filter((friend) => friend.shareListening);
    const roomSharers = friends.filter((friend) => friend.shareRooms);
    const presence = this.rooms.live(roomSharers.map((friend) => friend.userId));
    const now = this.now();
    const items = friends.filter((friend) => friend.shareListening || friend.shareRooms).map((friend) => {
      let nowPlaying: { title: string; artist: string; at: string } | null = null;
      let recent: Array<{ title: string; artist: string; at: string }> = [];
      if (listening.includes(friend)) {
        const live = this.#nowPlaying.get(friend.userId);
        if (live && now - live.at < NOW_PLAYING_TTL) {
          nowPlaying = { title: live.title, artist: live.artist, at: new Date(live.at).toISOString() };
        }
        const seen = new Set<string>();
        recent = this.taste.getWaveTasteSignals(friend.userId).listening
          .filter((item) => item.type !== "skipped" && item.type !== "disliked" && now - Date.parse(item.createdAt) < RECENT_WINDOW)
          .filter((item) => {
            const key = `${item.artist}::${item.title}`.toLowerCase();
            if (seen.has(key)) return false;
            seen.add(key);
            return true;
          })
          .slice(0, 5)
          .map((item) => ({ title: item.title, artist: item.artist, at: item.createdAt }));
        if (!nowPlaying && recent[0] && now - Date.parse(recent[0].at) < NOW_PLAYING_TTL) nowPlaying = recent[0];
      }
      const room = presence.find((entry) => entry.userId === friend.userId);
      return {
        friend: publicProfile(friend),
        nowPlaying,
        recent,
        room: room ? this.#roomCard(userId, room) : null
      };
    }).filter((item) => item.nowPlaying || item.recent.length || item.room);
    items.sort((a, b) => Number(Boolean(b.room)) - Number(Boolean(a.room)) ||
      Date.parse(b.nowPlaying?.at ?? b.recent[0]?.at ?? "0") - Date.parse(a.nowPlaying?.at ?? a.recent[0]?.at ?? "0"));
    return { items };
  }

  /** Private rooms are reported without a code unless the viewer was admitted before. */
  #roomCard(viewerId: string, room: LiveRoomPresence) {
    const canJoin = !room.isPrivate || this.rooms.isMember(room.code, viewerId);
    return {
      code: canJoin ? room.code : null,
      isPrivate: room.isPrivate,
      participants: room.participants,
      track: canJoin ? room.track : null
    };
  }

  compatibility(userId: string, friendId: string) {
    this.#requireFriend(userId, friendId);
    return compatibility(
      artistWeights(this.taste.getWaveTasteSignals(userId)),
      artistWeights(this.taste.getWaveTasteSignals(friendId))
    );
  }

  /** Blend: a shared daily mix built on top of DailyMixService from both tastes. */
  async blend(userId: string, friendId: string, options: { enabledProviders: WaveProviderName[]; tzOffsetMinutes: number }, access: WaveAccess) {
    this.#requireFriend(userId, friendId);
    const mine = artistWeights(this.taste.getWaveTasteSignals(userId));
    const theirs = artistWeights(this.taste.getWaveTasteSignals(friendId));
    const match = compatibility(mine, theirs);
    const a = topArtists(mine, 10);
    const b = topArtists(theirs, 10);
    const interleaved = [...match.sharedArtists.slice(0, 4)];
    for (let index = 0; index < Math.max(a.length, b.length); index += 1) {
      if (a[index]) interleaved.push(a[index]!);
      if (b[index]) interleaved.push(b[index]!);
    }
    const blocks = [...this.taste.getWaveBlocks(userId), ...this.taste.getWaveBlocks(friendId)].filter((block) => !block.removed);
    const owner = `blend:${[userId, friendId].sort().join(":")}`;
    const result = await this.mixes.build(owner, {
      favoriteArtists: interleaved,
      forgottenTracks: [],
      blockedArtists: blocks.filter((block) => block.kind === "artist").map((block) => block.key),
      blockedTracks: blocks.filter((block) => block.kind === "track").map((block) => block.key),
      enabledProviders: options.enabledProviders,
      tzOffsetMinutes: options.tzOffsetMinutes
    }, access);
    const friend = this.store.profile(friendId);
    const me = this.store.profile(userId);
    return {
      title: `Blend: ${me.displayName} × ${friend.displayName}`,
      compatibility: match,
      day: result.day,
      nextRefreshAt: result.nextRefreshAt,
      mixes: result.mixes.map((mix) => ({ ...mix, id: `blend:${mix.id}` }))
    };
  }

  #requireFriend(userId: string, friendId: string) {
    if (!this.store.areFriends(userId, friendId)) throw new ApiError("NOT_FRIENDS", "Доступно только для друзей", 403);
  }

  #sweep() {
    const now = this.now();
    for (const [key, value] of this.#nowPlaying) if (now - value.at >= NOW_PLAYING_TTL) this.#nowPlaying.delete(key);
  }
}

const providers = z.array(z.enum(["soundcloud", "yandex", "spotify", "vk"])).min(1).max(4).default(["soundcloud", "yandex"]);
const userIdParam = z.string().trim().min(1).max(100);
const profilePatch = z.object({
  displayName: z.string().trim().min(1).max(40).optional(),
  handle: z.string().trim().min(3).max(24).nullable().optional(),
  isPublic: z.boolean().optional(),
  shareListening: z.boolean().optional(),
  shareRooms: z.boolean().optional()
}).strict();
const targetSchema = z.object({
  userId: userIdParam.optional(),
  handle: z.string().trim().min(3).max(24).optional(),
  inviteCode: z.string().trim().min(6).max(40).optional()
}).strict().refine((value) => Boolean(value.userId || value.handle || value.inviteCode));
const nowPlayingSchema = z.object({
  title: z.string().trim().min(1).max(200),
  artist: z.string().trim().min(1).max(200),
  provider: z.enum(["soundcloud", "yandex", "spotify", "vk", "youtube"]).optional(),
  trackId: z.string().trim().min(1).max(200).optional()
}).strict();
const blendSchema = z.object({
  enabledProviders: providers,
  tzOffsetMinutes: z.number().int().min(-840).max(840).default(180)
}).strict();

export function createSocialRouter(
  service: SocialService,
  authenticate: Authenticate,
  waveAccess: (request: express.Request) => WaveAccess = () => ({})
) {
  const router = express.Router();
  const writes = new RateGate(60, 60_000);
  const reads = new RateGate(240, 60_000);
  const blends = new RateGate(10, 60_000);
  const store = service.store;

  router.use((request, response, next) => {
    response.setHeader("cache-control", "private, no-store");
    try {
      const userId = requireUser(authenticate, request);
      response.locals.userId = userId;
      (request.method === "GET" ? reads : writes).check(userId);
      store.profile(userId);
      next();
    } catch (error) {
      handle(() => { throw error; })(request, response);
    }
  });
  const me = (response: express.Response) => response.locals.userId as string;

  router.get("/profile", handle((_request, response) => ({ profile: store.profile(me(response)) })));
  router.patch("/profile", handle((request, response) =>
    ({ profile: store.updateProfile(me(response), parse(profilePatch, request.body, "Некорректные данные профиля")) })));
  router.post("/profile/invite", handle((_request, response) => ({ profile: store.rotateInvite(me(response)) })));

  router.get("/users/search", handle((request, response) => {
    const q = parse(z.string().trim().min(2).max(60), request.query.q, "Введите минимум 2 символа");
    return { users: store.search(me(response), q) };
  }));
  router.get("/users/:userId", handle((request, response) => {
    const profile = store.visibleProfile(me(response), parse(userIdParam, request.params.userId));
    if (!profile) throw new ApiError("USER_NOT_FOUND", "Пользователь не найден", 404);
    return { user: profile };
  }));

  router.get("/friends", handle((_request, response) => store.overview(me(response))));
  router.post("/friends/requests", handle((request, response) => {
    const target = store.resolveTarget(me(response), parse(targetSchema, request.body, "Укажите пользователя"));
    return { user: publicProfile(target), relation: store.request(me(response), target.userId) };
  }));
  router.post("/friends/requests/:userId/accept", handle((request, response) =>
    ({ relation: store.accept(me(response), parse(userIdParam, request.params.userId)) })));
  router.delete("/friends/requests/:userId", handle((request, response) => {
    store.dropRequest(me(response), parse(userIdParam, request.params.userId));
    response.status(204).end();
  }));
  router.delete("/friends/:userId", handle((request, response) => {
    store.removeFriend(me(response), parse(userIdParam, request.params.userId));
    response.status(204).end();
  }));
  router.post("/blocks", handle((request, response) => {
    const { userId } = parse(z.object({ userId: userIdParam }).strict(), request.body);
    if (!store.hasProfile(userId)) throw new ApiError("USER_NOT_FOUND", "Пользователь не найден", 404);
    store.block(me(response), userId);
    response.status(204).end();
  }));
  router.delete("/blocks/:userId", handle((request, response) => {
    store.unblock(me(response), parse(userIdParam, request.params.userId));
    response.status(204).end();
  }));

  router.put("/now-playing", handle((request, response) => {
    service.setNowPlaying(me(response), parse(nowPlayingSchema, request.body));
    response.status(204).end();
  }));
  router.delete("/now-playing", handle((_request, response) => {
    service.setNowPlaying(me(response), null);
    response.status(204).end();
  }));
  router.get("/feed", handle((_request, response) => service.feed(me(response))));
  router.get("/compatibility/:userId", handle((request, response) =>
    ({ compatibility: service.compatibility(me(response), parse(userIdParam, request.params.userId)) })));
  router.post("/blend/:userId", handle(async (request, response) => {
    blends.check(me(response));
    const options = parse(blendSchema, request.body ?? {});
    return service.blend(me(response), parse(userIdParam, request.params.userId), options, waveAccess(request));
  }));
  return router;
}
