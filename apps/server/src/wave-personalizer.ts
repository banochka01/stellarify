import { createHash } from "node:crypto";
import { z } from "zod";
import { AccountStore, type WaveTasteSignals, type WaveTrackSignal } from "./account-store.js";
import type { WaveFeedbackType, WaveProviderName } from "./wave.js";

const agentProfileSchema = z.object({
  seedQueries: z.array(z.string().trim().min(1).max(120)).max(5).default([]),
  artistPreferences: z.array(z.object({
    artist: z.string().trim().min(1).max(200),
    weight: z.number().min(-1).max(1)
  }).strict()).max(20).default([]),
  discoveryDelta: z.number().min(-.15).max(.15).default(0)
}).strict();

const completionSchema = z.object({
  choices: z.array(z.object({
    message: z.object({ content: z.string() }).passthrough()
  }).passthrough()).min(1)
}).passthrough();

export type WavePersonalization = {
  seedQueries: string[];
  artistWeights: Record<string, number>;
  discoveryDelta: number;
  source: "agentrouter" | "deterministic";
};

export type WavePersonalizerConfig = {
  apiKey?: string;
  baseUrl?: string;
  model?: string;
  timeoutMs?: number;
  cacheMs?: number;
};

type Fetch = typeof fetch;
type CachedProfile = { signature: string; expiresAt: number; value: WavePersonalization };

/**
 * Converts account-owned taste signals into small search/ranking parameters.
 * The LLM never returns playable URLs or owns the final queue: provider search,
 * repeat protection and deterministic ranking remain authoritative.
 */
export class WavePersonalizer {
  readonly enabled: boolean;
  readonly model: string;
  private readonly apiKey?: string;
  private readonly endpoint: URL;
  private readonly timeoutMs: number;
  private readonly cacheMs: number;
  private readonly cache = new Map<string, CachedProfile>();
  private readonly pending = new Map<string, Promise<WavePersonalization>>();

  constructor(
    private readonly accounts: AccountStore,
    config: WavePersonalizerConfig = {},
    private readonly request: Fetch = fetch,
    private readonly now: () => number = Date.now
  ) {
    this.apiKey = config.apiKey?.trim() || undefined;
    this.enabled = this.apiKey !== undefined;
    this.model = config.model?.trim() || "glm-5.2";
    this.endpoint = chatCompletionsEndpoint(config.baseUrl || "https://co.agentrouter.org/v1");
    this.timeoutMs = bounded(config.timeoutMs, 1_000, 10_000, 4_500);
    this.cacheMs = bounded(config.cacheMs, 60_000, 24 * 60 * 60_000, 60 * 60_000);
  }

  async personalize(userId: string): Promise<WavePersonalization> {
    const signals = this.accounts.getWaveTasteSignals(userId);
    const signature = createHash("sha256").update(JSON.stringify(signals)).digest("base64url");
    const cached = this.cache.get(userId);
    if (cached && cached.signature === signature && cached.expiresAt > this.now()) return cached.value;
    const active = this.pending.get(userId);
    if (active) return active;
    const operation = this.#build(signals).finally(() => this.pending.delete(userId));
    this.pending.set(userId, operation);
    const value = await operation;
    this.cache.set(userId, { signature, expiresAt: this.now() + this.cacheMs, value });
    if (this.cache.size > 2_000) this.#pruneCache();
    return value;
  }

  invalidate(userId: string) {
    this.cache.delete(userId);
  }

  recordFeedback(
    userId: string,
    event: {
      eventId: string;
      type: WaveFeedbackType;
      provider: WaveProviderName;
      trackId: string;
      playedDurationMs: number;
    },
    track: WaveTrackSignal
  ) {
    this.accounts.recordWaveFeedback(userId, event, track);
    this.invalidate(userId);
  }

  async #build(signals: WaveTasteSignals): Promise<WavePersonalization> {
    const fallback = deterministicProfile(signals);
    if (!this.apiKey || !hasTasteSignals(signals)) return fallback;
    try {
      const response = await this.request(this.endpoint, {
        method: "POST",
        redirect: "error",
        headers: {
          authorization: `Bearer ${this.apiKey}`,
          "content-type": "application/json"
        },
        body: JSON.stringify({
          model: this.model,
          temperature: .1,
          max_tokens: 350,
          messages: [
            {
              role: "system",
              content: "You tune a music recommender. Return only compact JSON with seedQueries (artist, genre or mood searches, max 5), artistPreferences ({artist, weight -1..1}, max 20), and discoveryDelta (-0.15..0.15). Infer taste from completed/liked tracks, down-rank skipped/disliked tracks, and use favorites/playlists. Never invent track IDs, URLs or providers."
            },
            {
              role: "user",
              content: JSON.stringify(minimizeSignals(signals))
            }
          ]
        }),
        signal: AbortSignal.timeout(this.timeoutMs)
      });
      if (!response.ok) throw new Error(`AgentRouter returned ${response.status}`);
      const completion = completionSchema.parse(await response.json());
      const parsed = agentProfileSchema.parse(parseJsonObject(completion.choices[0]!.message.content));
      return mergeProfiles(fallback, parsed);
    } catch (error) {
      console.warn("Wave personalization fell back to local ranking", error instanceof Error ? error.message : "unknown error");
      return fallback;
    }
  }

  #pruneCache() {
    const now = this.now();
    for (const [userId, entry] of this.cache) if (entry.expiresAt <= now) this.cache.delete(userId);
    while (this.cache.size > 2_000) this.cache.delete(this.cache.keys().next().value!);
  }
}

function deterministicProfile(signals: WaveTasteSignals): WavePersonalization {
  const weights = new Map<string, { artist: string; score: number }>();
  const add = (track: WaveTrackSignal, score: number) => {
    const key = normalize(track.artist);
    if (!key) return;
    const previous = weights.get(key);
    weights.set(key, { artist: track.artist.trim(), score: (previous?.score ?? 0) + score });
  };
  signals.favorites.forEach((track) => add(track, 4));
  signals.playlistTracks.forEach((track) => add(track, 1.5));
  signals.listening.forEach((event, index) => {
    const outcome = event.type === "liked" ? 5
      : event.type === "finished" ? 3
      : event.type === "disliked" ? -5
      : event.type === "skipped" ? -2
      : .25;
    add(event, outcome / (1 + index / 30));
  });
  const ranked = [...weights.values()].sort((a, b) => b.score - a.score);
  const scale = Math.max(1, ...ranked.map((entry) => Math.abs(entry.score)));
  return {
    seedQueries: ranked.filter((entry) => entry.score > 0).slice(0, 5).map((entry) => entry.artist),
    artistWeights: Object.fromEntries(ranked.slice(0, 20).map((entry) => [normalize(entry.artist), clamp(entry.score / scale, -1, 1)])),
    discoveryDelta: 0,
    source: "deterministic"
  };
}

function mergeProfiles(
  fallback: WavePersonalization,
  profile: z.infer<typeof agentProfileSchema>
): WavePersonalization {
  const artistWeights = { ...fallback.artistWeights };
  for (const preference of profile.artistPreferences) {
    const key = normalize(preference.artist);
    if (key) artistWeights[key] = clamp((artistWeights[key] ?? 0) * .4 + preference.weight * .6, -1, 1);
  }
  const seedQueries = [...new Set([...profile.seedQueries, ...fallback.seedQueries])].slice(0, 5);
  return { seedQueries, artistWeights, discoveryDelta: profile.discoveryDelta, source: "agentrouter" };
}

function minimizeSignals(signals: WaveTasteSignals) {
  const track = (value: WaveTrackSignal) => ({
    title: value.title,
    artist: value.artist,
    ...(value.album ? { album: value.album } : {})
  });
  return {
    recentListening: signals.listening.slice(0, 60).map((event) => ({
      ...track(event),
      outcome: event.type,
      playedSeconds: Math.round(event.playedDurationMs / 1_000)
    })),
    favorites: signals.favorites.slice(0, 50).map(track),
    playlistTracks: signals.playlistTracks.slice(0, 100).map(track)
  };
}

function hasTasteSignals(signals: WaveTasteSignals) {
  return signals.listening.length + signals.favorites.length + signals.playlistTracks.length > 0;
}

function parseJsonObject(value: string) {
  const start = value.indexOf("{");
  const end = value.lastIndexOf("}");
  if (start < 0 || end <= start) throw new Error("AgentRouter did not return JSON");
  return JSON.parse(value.slice(start, end + 1)) as unknown;
}

function chatCompletionsEndpoint(value: string) {
  const base = new URL(value);
  if (base.protocol !== "https:" || base.username || base.password) {
    throw new Error("AGENTROUTER_BASE_URL must be credential-free HTTPS");
  }
  base.pathname = `${base.pathname.replace(/\/$/u, "")}/chat/completions`;
  return base;
}

function bounded(value: number | undefined, min: number, max: number, fallback: number) {
  return Number.isFinite(value) ? Math.min(max, Math.max(min, Math.trunc(value!))) : fallback;
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function normalize(value: string) {
  return value.toLocaleLowerCase("ru").replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}
