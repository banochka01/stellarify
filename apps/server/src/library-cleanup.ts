import express from "express";
import { z } from "zod";
import { handle, parse, RateGate, requireUser, type Authenticate } from "./api-helpers.js";
import type { ProviderAccess, ProviderTrack } from "./provider-gateway.js";
import { confidenceAtLeast, matchTrack, normalizeArtist, scoreTrackPair, searchQueryFor, type MatchConfidence } from "./track-matcher.js";
import type { WaveProviderName } from "./wave.js";

type Library = {
  favorites: Array<Record<string, unknown>>;
  playlists: Array<{ id: string; name: string; tracks: Array<{ position: number; track: Record<string, unknown> }> }>;
};

type Search = (provider: WaveProviderName, query: string, limit: number, access?: ProviderAccess) => Promise<ProviderTrack[]>;

export type LibraryItem = {
  trackId: string;
  title: string;
  artist: string;
  durationMs?: number;
  isrc?: string;
  providers: string[];
  /** "favorites" or a playlist id. */
  locations: Array<{ kind: "favorites" } | { kind: "playlist"; playlistId: string; playlistName: string }>;
};

export type DuplicateGroup = {
  keep: LibraryItem;
  duplicates: Array<LibraryItem & { confidence: MatchConfidence; score: number }>;
  crossProvider: boolean;
};

export type Replacement = {
  item: LibraryItem;
  reason: "no_sources" | "provider_disabled" | "reported_unavailable";
  suggestion: (ProviderTrack & { provider: WaveProviderName; confidence: MatchConfidence; score: number }) | null;
};

const MAX_REPLACEMENT_LOOKUPS = 25;

/** Flattens favorites and playlist tracks into unique library items (one per track id). */
export function collectLibraryItems(library: Library): LibraryItem[] {
  const items = new Map<string, LibraryItem>();
  const add = (track: Record<string, unknown>, location: LibraryItem["locations"][number]) => {
    const trackId = typeof track.id === "string" ? track.id : "";
    const title = typeof track.title === "string" ? track.title : "";
    const artist = typeof track.artist === "string" ? track.artist : "";
    if (!trackId || !title || !artist) return;
    let item = items.get(trackId);
    if (!item) {
      const sources = Array.isArray(track.sources) ? track.sources as Array<Record<string, unknown>> : [];
      const providers = [...new Set(sources.map((source) => String(source.provider ?? "")).filter(Boolean))];
      const preferred = typeof track.preferredProvider === "string" ? track.preferredProvider : undefined;
      if (preferred && providers.includes(preferred)) providers.sort((a, b) => Number(b === preferred) - Number(a === preferred));
      const isrc = sources.map((source) => (source.metadata as Record<string, unknown> | undefined)?.isrc).find((value) => typeof value === "string");
      item = {
        trackId,
        title,
        artist,
        ...(typeof track.duration === "number" && track.duration > 0 ? { durationMs: track.duration } : {}),
        ...(typeof isrc === "string" ? { isrc } : {}),
        providers,
        locations: []
      };
      items.set(trackId, item);
    }
    item.locations.push(location);
  };
  for (const track of library.favorites) add(track, { kind: "favorites" });
  for (const playlist of library.playlists) {
    for (const entry of playlist.tracks) add(entry.track, { kind: "playlist", playlistId: playlist.id, playlistName: playlist.name });
  }
  return [...items.values()];
}

/** Same recording saved several times (often from different providers), grouped with a suggested keeper. */
export function findDuplicates(items: LibraryItem[], providerPriority: string[] = []): DuplicateGroup[] {
  const buckets = new Map<string, LibraryItem[]>();
  for (const item of items) {
    const key = normalizeArtist(item.artist);
    if (!key) continue;
    const bucket = buckets.get(key) ?? [];
    bucket.push(item);
    buckets.set(key, bucket);
  }
  const parent = new Map<string, string>();
  const find = (id: string): string => {
    const next = parent.get(id) ?? id;
    if (next === id) return id;
    const root = find(next);
    parent.set(id, root);
    return root;
  };
  const linked = new Set<string>();
  const scores = new Map<string, { confidence: MatchConfidence; score: number }>();
  for (const bucket of buckets.values()) {
    if (bucket.length < 2 || bucket.length > 2_000) continue;
    for (let i = 0; i < bucket.length; i += 1) {
      for (let j = i + 1; j < bucket.length; j += 1) {
        const a = bucket[i]!;
        const b = bucket[j]!;
        const result = scoreTrackPair(a, b);
        if (!confidenceAtLeast(result.confidence, "high")) continue;
        parent.set(find(b.trackId), find(a.trackId));
        linked.add(a.trackId).add(b.trackId);
        scores.set(`${a.trackId}\u0000${b.trackId}`, result);
        scores.set(`${b.trackId}\u0000${a.trackId}`, result);
      }
    }
  }
  const groups = new Map<string, LibraryItem[]>();
  for (const item of items) {
    if (!linked.has(item.trackId)) continue;
    const root = find(item.trackId);
    const group = groups.get(root) ?? [];
    group.push(item);
    groups.set(root, group);
  }
  const rank = (item: LibraryItem) => {
    const priority = item.providers.map((provider) => providerPriority.indexOf(provider)).filter((index) => index >= 0);
    return [
      priority.length ? -Math.min(...priority) : -999,
      item.locations.length,
      item.providers.length,
      item.durationMs ? 1 : 0
    ];
  };
  const better = (a: LibraryItem, b: LibraryItem) => {
    const left = rank(a);
    const right = rank(b);
    for (let index = 0; index < left.length; index += 1) if (left[index] !== right[index]) return left[index]! > right[index]!;
    return a.trackId < b.trackId;
  };
  return [...groups.values()].filter((group) => group.length > 1).map((group) => {
    const keep = group.reduce((best, item) => (better(item, best) ? item : best));
    const duplicates = group.filter((item) => item !== keep).map((item) => ({
      ...item,
      ...(scores.get(`${keep.trackId}\u0000${item.trackId}`) ?? scoreTrackPair(keep, item))
    }));
    const providers = new Set(group.map((item) => item.providers[0] ?? "unknown"));
    return { keep, duplicates, crossProvider: providers.size > 1 };
  });
}

export class LibraryCleanupService {
  constructor(private readonly library: (userId: string) => Library, private readonly search: Search) {}

  async analyze(userId: string, options: {
    enabledProviders: WaveProviderName[];
    unavailableTrackIds: string[];
    access?: Partial<Record<WaveProviderName, ProviderAccess>>;
  }) {
    const items = collectLibraryItems(this.library(userId));
    const duplicates = findDuplicates(items, options.enabledProviders);
    const reported = new Set(options.unavailableTrackIds);
    const enabled = new Set<string>(options.enabledProviders);
    const broken: Array<Omit<Replacement, "suggestion">> = [];
    for (const item of items) {
      if (reported.has(item.trackId)) broken.push({ item, reason: "reported_unavailable" });
      else if (!item.providers.length) broken.push({ item, reason: "no_sources" });
      else if (!item.providers.some((provider) => enabled.has(provider) || provider === "youtube")) broken.push({ item, reason: "provider_disabled" });
    }
    const replacements: Replacement[] = [];
    for (const [index, entry] of broken.entries()) {
      if (index >= MAX_REPLACEMENT_LOOKUPS) {
        replacements.push({ ...entry, suggestion: null });
        continue;
      }
      replacements.push({ ...entry, suggestion: await this.#replacement(entry.item, options) });
    }
    return {
      scanned: items.length,
      duplicates,
      replacements,
      truncated: broken.length > MAX_REPLACEMENT_LOOKUPS
    };
  }

  async #replacement(item: LibraryItem, options: { enabledProviders: WaveProviderName[]; access?: Partial<Record<WaveProviderName, ProviderAccess>> }) {
    const query = searchQueryFor(item);
    // Prefer a provider other than the one that is failing.
    const providers = [...options.enabledProviders].sort((a, b) => Number(item.providers[0] === a) - Number(item.providers[0] === b)).slice(0, 2);
    for (const provider of providers) {
      const candidates = await this.search(provider, query, 8, options.access?.[provider]).catch(() => [] as ProviderTrack[]);
      const match = matchTrack(item, candidates);
      if (match.candidate && confidenceAtLeast(match.confidence, "high")) {
        return { ...match.candidate, provider, confidence: match.confidence, score: match.score };
      }
    }
    return null;
  }
}

const cleanupSchema = z.object({
  enabledProviders: z.array(z.enum(["soundcloud", "yandex", "spotify", "vk"])).min(1).max(4).default(["soundcloud", "yandex"]),
  unavailableTrackIds: z.array(z.string().trim().min(1).max(300)).max(500).default([])
}).strict();

export function createLibraryCleanupRouter(
  service: LibraryCleanupService,
  authenticate: Authenticate,
  access: (request: express.Request) => Partial<Record<WaveProviderName, ProviderAccess>> = () => ({})
) {
  const router = express.Router();
  const gate = new RateGate(6, 60_000);
  router.post("/", handle(async (request, response) => {
    response.setHeader("cache-control", "private, no-store");
    const userId = requireUser(authenticate, request);
    gate.check(userId);
    const input = parse(cleanupSchema, request.body ?? {}, "Некорректный запрос чистки");
    return service.analyze(userId, { ...input, access: access(request) });
  }));
  return router;
}
