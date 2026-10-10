import { randomUUID } from "node:crypto";
import type { ProviderAccess, ProviderTrack } from "./provider-gateway.js";
import { ProviderGateway } from "./provider-gateway.js";
import { YandexAdapter } from "./yandex.js";
import { WavePersonalizer, type WaveIntent, type WavePersonalization } from "./wave-personalizer.js";

export type WaveProviderName = "soundcloud" | "yandex" | "spotify" | "vk";
export type WaveAccess = Partial<Record<WaveProviderName, ProviderAccess>>;
export type WaveFeedbackType = "started" | "finished" | "skipped" | "liked" | "disliked";

export interface WaveRequest {
  prompt?: string;
  seedQueries: string[];
  excludedTerms?: string[];
  enabledProviders: WaveProviderName[];
  discovery: number;
  mood: "fun" | "active" | "calm" | "sad" | "all";
  language: "not-russian" | "russian" | "any";
  /** "Запустить радио" seed: endless queue of tracks similar to this one. */
  radioSeed?: { title: string; artist: string };
  /** "Не предлагать": normalized artist names and `artist::title` keys. */
  blockedArtists?: string[];
  blockedTracks?: string[];
  /** Listener-local clock so the wave can follow time of day and weekday. */
  localHour?: number;
  weekday?: number;
}

export type WaveContext = "morning" | "focus" | "evening" | "night" | "weekend";

/** Explainable time-of-day/weekday adjustment applied only when the user left mood on "all". */
export function waveContext(hour: number | undefined, weekday: number | undefined): WaveContext | undefined {
  if (hour === undefined || !Number.isInteger(hour) || hour < 0 || hour > 23) return undefined;
  const weekend = weekday === 6 || weekday === 7;
  if (hour < 6 || hour >= 23) return "night";
  if (hour < 11) return "morning";
  if (hour < 18) return weekend ? "weekend" : "focus";
  return "evening";
}

export function applyWaveContext(request: WaveRequest): { request: WaveRequest; context?: WaveContext } {
  const context = waveContext(request.localHour, request.weekday);
  if (!context || request.mood !== "all" || request.radioSeed) return { request, ...(context ? { context } : {}) };
  const tuned: Record<WaveContext, { mood: WaveRequest["mood"]; discovery: number }> = {
    morning: { mood: "fun", discovery: 0 },
    focus: { mood: "calm", discovery: -.05 },
    evening: { mood: "all", discovery: .05 },
    night: { mood: "calm", discovery: -.05 },
    weekend: { mood: "active", discovery: .1 }
  };
  const value = tuned[context];
  return {
    context,
    request: { ...request, mood: value.mood, discovery: clamp(request.discovery + value.discovery, 0, 1) }
  };
}

/** Skip learning: an early skip is negative, a full listen or a repeat is positive. */
export const EARLY_SKIP_MS = 30_000;
export function feedbackSignal(type: WaveFeedbackType, playedDurationMs: number): -1 | 0 | 1 {
  if (type === "disliked") return -1;
  if (type === "skipped") return playedDurationMs < EARLY_SKIP_MS ? -1 : 0;
  if (type === "finished" || type === "liked") return 1;
  return 0;
}

export interface WaveItem extends ProviderTrack {
  provider: WaveProviderName;
  batchId?: string;
  score: number;
  lane: "safe" | "adjacent" | "wild";
  reason?: string;
}

interface WaveSession {
  id: string;
  owner: string;
  userId?: string;
  request: WaveRequest;
  personalization?: WavePersonalization;
  intent?: WaveIntent;
  station?: string;
  batchId?: string;
  queue?: string;
  recentTracks: string[];
  recentArtists: string[];
  recentAlbums: string[];
  feedbackIds: Set<string>;
  tracks: Map<string, WaveItem>;
  lastItems: WaveItem[];
  currentTrackKey?: string;
  currentPositionMs: number;
  expiresAt: number;
  context?: WaveContext;
  artistBias: Record<string, number>;
  playCounts: Map<string, number>;
}

export class WaveService {
  private readonly sessions = new Map<string, WaveSession>();

  constructor(
    private readonly gateway: ProviderGateway,
    private readonly yandex: YandexAdapter,
    private readonly personalizer?: WavePersonalizer,
    private readonly now: () => number = Date.now
  ) {}

  async start(
    request: WaveRequest,
    access: WaveAccess = {},
    owner = "",
    userId?: string,
    tasteUserIds: string[] = userId ? [userId] : []
  ) {
    this.sweep();
    if (this.sessions.size >= 2000) throw new WaveSessionError();
    const [personalization, intent] = await Promise.all([
      this.personalizer ? this.personalizer.personalizeGroup(tasteUserIds) : undefined,
      request.prompt?.trim() && this.personalizer
        ? this.personalizer.interpretPrompt(request.prompt, request)
        : undefined
    ]);
    const interpretedRequest = intent ? {
      ...request,
      seedQueries: [...new Set([...intent.seedQueries, ...request.seedQueries])].slice(0, 10),
      excludedTerms: [...new Set([...(request.excludedTerms ?? []), ...intent.excludedTerms])].slice(0, 10),
      discovery: intent.discovery,
      mood: intent.mood,
      language: intent.language
    } : request;
    const personalizedRequest = personalization ? {
      ...interpretedRequest,
      seedQueries: [...new Set([...interpretedRequest.seedQueries, ...personalization.seedQueries])].slice(0, 10),
      discovery: clamp(interpretedRequest.discovery + personalization.discoveryDelta, 0, 1)
    } : interpretedRequest;
    const radioRequest = request.radioSeed ? {
      ...personalizedRequest,
      // Radio stays close to the seed: its artist first, then the track itself.
      seedQueries: [...new Set([
        request.radioSeed.artist,
        `${request.radioSeed.artist} ${request.radioSeed.title}`,
        ...personalizedRequest.seedQueries
      ])].slice(0, 10),
      discovery: Math.min(personalizedRequest.discovery, .45)
    } : personalizedRequest;
    const contextual = request.prompt?.trim() ? { request: radioRequest } : applyWaveContext(radioRequest);
    const session: WaveSession = {
      id: randomUUID(),
      owner,
      ...(userId ? { userId } : {}),
      request: contextual.request,
      ...("context" in contextual && contextual.context ? { context: contextual.context } : {}),
      artistBias: {},
      playCounts: new Map(),
      ...(personalization ? { personalization } : {}),
      ...(intent ? { intent } : {}),
      recentTracks: [],
      recentArtists: [],
      recentAlbums: [],
      feedbackIds: new Set(),
      tracks: new Map(),
      lastItems: [],
      currentPositionMs: 0,
      expiresAt: this.now() + 30 * 60_000
    };
    this.sessions.set(session.id, session);
    const items = await this.fill(session, access);
    return this.response(session, items);
  }

  active(owner = "") {
    this.sweep();
    const session = [...this.sessions.values()]
      .filter((value) => value.owner === owner)
      .sort((a, b) => b.expiresAt - a.expiresAt)[0];
    if (!session) return undefined;
    const buffered = [...session.tracks.values()];
    const currentIndex = session.currentTrackKey
      ? buffered.findIndex((item) => `${item.provider}:${item.id}` === session.currentTrackKey)
      : -1;
    const resumable = currentIndex >= 0
      ? buffered.slice(currentIndex, currentIndex + 50)
      : session.lastItems;
    return this.response(session, resumable, false);
  }

  async next(id: string, access: WaveAccess = {}, owner = "") {
    const session = this.requireSession(id, owner);
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
    access: WaveAccess = {},
    owner = ""
  ) {
    const session = this.requireSession(id, owner);
    if (session.feedbackIds.has(event.eventId)) return { accepted: true, duplicate: true };
    session.feedbackIds.add(event.eventId);
    if (session.feedbackIds.size > 500) {
      const first = session.feedbackIds.values().next().value;
      if (first) session.feedbackIds.delete(first);
    }
    session.expiresAt = this.now() + 30 * 60_000;
    const track = session.tracks.get(`${event.provider}:${event.trackId}`);
    if (event.type === "started") {
      session.currentTrackKey = `${event.provider}:${event.trackId}`;
      if (track) {
        const key = trackKey(track);
        const plays = (session.playCounts.get(key) ?? 0) + 1;
        session.playCounts.set(key, plays);
        // A repeat is a strong positive signal for that artist.
        if (plays > 1) bumpArtist(session, track.artist, .5);
      }
    }
    if (track) {
      const signal = feedbackSignal(event.type, event.playedDurationMs);
      if (signal !== 0) bumpArtist(session, track.artist, signal * (event.type === "disliked" ? 1 : .35));
      if (event.type === "disliked") {
        session.request.blockedTracks = [...new Set([...(session.request.blockedTracks ?? []), trackKey(track)])];
      }
    }
    if (session.userId && track && this.personalizer) {
      this.personalizer.recordFeedback(session.userId, event, {
        title: track.title,
        artist: track.artist,
        ...(track.album ? { album: track.album } : {})
      });
    }
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

  stop(id: string, owner = "") {
    if (this.sessions.has(id)) this.requireSession(id, owner);
    return this.sessions.delete(id);
  }

  checkpoint(
    id: string,
    value: { provider: WaveProviderName; trackId: string; positionMs: number },
    owner = ""
  ) {
    const session = this.requireSession(id, owner);
    const key = `${value.provider}:${value.trackId}`;
    if (!session.tracks.has(key)) throw new WaveSessionError();
    session.currentTrackKey = key;
    session.currentPositionMs = Math.max(0, Math.trunc(value.positionMs));
    session.expiresAt = this.now() + 30 * 60_000;
    return { accepted: true };
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
    const excluded = (session.request.excludedTerms ?? []).map(normalize).filter(Boolean);
    const blockedArtists = new Set((session.request.blockedArtists ?? []).map(normalize));
    const blockedTracks = new Set((session.request.blockedTracks ?? []).map((key) => {
      const [artist = "", title = ""] = key.split("::");
      return `${normalize(artist)}::${normalize(title)}`;
    }));
    const allowed = candidates.filter((item) => {
      if (blockedArtists.has(normalize(item.artist)) || blockedTracks.has(trackKey(item))) return false;
      if ((session.artistBias[normalize(item.artist)] ?? 0) <= -1) return false;
      if (excluded.length === 0) return true;
      const haystack = normalize(`${item.artist} ${item.title} ${item.album ?? ""}`);
      return !excluded.some((term) => haystack.includes(term));
    });
    const items = rerank(allowed, session, 20, session.request.discovery).map((item) => ({
      ...item,
      reason: session.request.radioSeed
        ? `Радио: ${session.request.radioSeed.artist}`
        : item.lane === "safe"
        ? "Знакомое направление"
        : item.lane === "wild"
          ? "Немного нового"
          : "Рядом с вашим вкусом"
    }));
    session.lastItems = items;
    for (const item of items) {
      session.tracks.set(`${item.provider}:${item.id}`, item);
      session.recentTracks.push(trackKey(item));
      session.recentArtists.push(normalize(item.artist));
      if (item.album) session.recentAlbums.push(normalize(item.album));
    }
    session.recentTracks = session.recentTracks.slice(-100);
    session.recentArtists = session.recentArtists.slice(-10);
    session.recentAlbums = session.recentAlbums.slice(-5);
    while (session.tracks.size > 100) session.tracks.delete(session.tracks.keys().next().value!);
    const lastYandex = [...items].reverse().find((item) => item.provider === "yandex");
    if (lastYandex) session.queue = lastYandex.id;
    return items;
  }

  private item(provider: WaveProviderName, track: ProviderTrack, lane: WaveItem["lane"], base: number, batchId?: string): WaveItem {
    return { ...track, provider, lane, batchId, score: base };
  }

  private response(session: WaveSession, items: WaveItem[], extend = true) {
    if (extend) session.expiresAt = this.now() + 30 * 60_000;
    return {
      sessionId: session.id,
      items,
      expiresAt: new Date(session.expiresAt).toISOString(),
      personalization: session.personalization?.source ?? "none",
      intent: session.intent ? {
        summary: session.intent.summary,
        source: session.intent.source,
        discovery: session.request.discovery,
        mood: session.request.mood,
        language: session.request.language
      } : undefined,
      context: session.context,
      radio: session.request.radioSeed ? true : undefined,
      currentTrackKey: session.currentTrackKey,
      positionMs: session.currentPositionMs
    };
  }

  private requireSession(id: string, owner: string) {
    this.sweep();
    const session = this.sessions.get(id);
    if (!session || session.owner !== owner) throw new WaveSessionError();
    return session;
  }

  private sweep() {
    const now = this.now();
    for (const [id, session] of this.sessions) if (session.expiresAt <= now) this.sessions.delete(id);
  }
}

export class WaveSessionError extends Error {}

export function rerank(
  candidates: WaveItem[],
  history: Pick<WaveSession, "recentTracks" | "recentArtists" | "recentAlbums"> & Partial<Pick<WaveSession, "personalization" | "artistBias">>,
  limit: number,
  discovery: number
) {
  const unique = new Map<string, WaveItem>();
  for (const candidate of candidates) {
    const key = trackKey(candidate);
    const old = unique.get(key);
    const providerBonus = candidate.provider === "soundcloud" ? .02 : 0;
    const discoveryBonus = candidate.lane === "wild" ? discovery * .12 : candidate.lane === "safe" ? (1 - discovery) * .12 : .06;
    const tasteBonus = (history.personalization?.artistWeights[normalize(candidate.artist)] ?? 0) * .12;
    const sessionBias = clamp(history.artistBias?.[normalize(candidate.artist)] ?? 0, -1, 1) * .15;
    const scored = { ...candidate, score: candidate.score + providerBonus + discoveryBonus + tasteBonus + sessionBias };
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

function bumpArtist(session: WaveSession, artist: string, delta: number) {
  const key = normalize(artist);
  if (!key) return;
  session.artistBias[key] = clamp((session.artistBias[key] ?? 0) + delta, -1.5, 1.5);
}

export function trackKey(track: Pick<ProviderTrack, "artist" | "title">) {
  return `${normalize(track.artist)}::${normalize(track.title)}`;
}

export function normalize(value: string) {
  return value.toLocaleLowerCase("ru").replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}
