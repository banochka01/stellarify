import { createHash } from "node:crypto";
import type { ProviderAccess, ProviderTrack } from "./provider-gateway.js";
import { normalize, trackKey, type WaveAccess, type WaveItem, type WaveProviderName } from "./wave.js";

export type DailyMixKind = "morning" | "focus" | "evening" | "discovery";

export interface DailyMix {
  id: string;
  kind: DailyMixKind;
  title: string;
  subtitle: string;
  seedArtists: string[];
  tracks: WaveItem[];
}

export interface DailyMixInput {
  favoriteArtists: string[];
  /** Tracks the listener liked once but has not played for a long time. */
  forgottenTracks: Array<{ title: string; artist: string }>;
  blockedArtists: string[];
  blockedTracks: string[];
  enabledProviders: WaveProviderName[];
  /** Minutes east of UTC (e.g. Moscow = 180). Mixes refresh at 06:00 local time. */
  tzOffsetMinutes: number;
}

export interface DailyMixesResult {
  day: string;
  refreshedAt: string;
  nextRefreshAt: string;
  mixes: DailyMix[];
}

type Search = (provider: WaveProviderName, query: string, limit: number, access?: ProviderAccess) => Promise<ProviderTrack[]>;

const REFRESH_HOUR = 6;
const MIX_SIZE = 25;
const DAY = 24 * 60 * 60_000;

/**
 * "Ваш день": three to five deterministic mixes per listener and local day.
 * They are built from favorite artists, artists that co-occur with them in
 * provider search (a lightweight "similar artists" signal) and tracks that
 * have not been played for a long time. Results are cached until the next
 * local morning so the Home screen stays stable throughout the day.
 */
export class DailyMixService {
  private readonly cache = new Map<string, { expiresAt: number; value: DailyMixesResult }>();
  private readonly pending = new Map<string, Promise<DailyMixesResult>>();

  constructor(private readonly search: Search, private readonly now: () => number = Date.now) {}

  async build(owner: string, input: DailyMixInput, access: WaveAccess = {}): Promise<DailyMixesResult> {
    const window = mixWindow(this.now(), input.tzOffsetMinutes);
    const signature = createHash("sha256").update(JSON.stringify([
      owner, window.day, input.favoriteArtists.slice(0, 12), input.forgottenTracks.slice(0, 20),
      input.blockedArtists, input.blockedTracks, input.enabledProviders
    ])).digest("base64url");
    const cached = this.cache.get(signature);
    if (cached && cached.expiresAt > this.now()) return cached.value;
    const running = this.pending.get(signature);
    if (running) return running;
    const task = this.compose(input, access, window).then((value) => {
      this.sweep();
      if (this.cache.size >= 5000) this.cache.delete(this.cache.keys().next().value!);
      this.cache.set(signature, { expiresAt: window.next, value });
      return value;
    }).finally(() => this.pending.delete(signature));
    this.pending.set(signature, task);
    return task;
  }

  private async compose(input: DailyMixInput, access: WaveAccess, window: MixWindow): Promise<DailyMixesResult> {
    const blockedArtists = new Set(input.blockedArtists.map(normalize));
    const blockedTracks = new Set(input.blockedTracks.map(normalizeTrackKey));
    const favorites = unique(input.favoriteArtists).filter((artist) => !blockedArtists.has(normalize(artist)));
    const searchProviders = input.enabledProviders.slice(0, 2);
    const rotated = rotate(favorites, seededIndex(window.day, favorites.length));
    const allowed = (item: WaveItem) => !blockedArtists.has(normalize(item.artist)) && !blockedTracks.has(trackKey(item));

    const run = async (queries: string[], perQuery: number, lane: WaveItem["lane"]) => {
      const tasks = searchProviders.flatMap((provider) => queries.map(async (query) => {
        try {
          return (await this.search(provider, query, perQuery, access[provider]))
            .map((track, rank): WaveItem => ({ ...track, provider, lane, score: 1 - rank * .03 }));
        } catch {
          return [];
        }
      }));
      return (await Promise.all(tasks)).flat().filter(allowed);
    };

    const morningArtists = rotated.slice(0, 3);
    const pick = (from: number) => unique([...rotated.slice(from, from + 3), ...rotated.slice(1)]).slice(0, 3);
    const focusArtists = pick(3);
    const eveningArtists = pick(6);
    const [morning, focus, evening, forgotten, related] = await Promise.all([
      run(morningArtists.length ? morningArtists : ["хиты утро"], 10, "safe"),
      run(focusArtists.length ? focusArtists.map((artist) => `${artist} instrumental`) : ["lo-fi focus"], 8, "adjacent"),
      run(eveningArtists.length ? eveningArtists : ["вечерний чилл"], 10, "safe"),
      run(input.forgottenTracks.slice(0, 10).map((track) => `${track.artist} ${track.title}`), 2, "safe"),
      run(rotated.slice(0, 4).map((artist) => `${artist} feat`), 12, "wild")
    ]);
    const favoriteSet = new Set(favorites.map(normalize));
    const discoveries = related.filter((item) => !favoriteSet.has(normalize(item.artist)));
    const similarArtists = unique(discoveries.map((item) => item.artist)).slice(0, 4);

    const mixes: DailyMix[] = [];
    const add = (kind: DailyMixKind, title: string, subtitle: string, seeds: string[], items: WaveItem[]) => {
      const tracks = diversify(shuffle(items, `${window.day}:${kind}`), MIX_SIZE);
      if (tracks.length >= 5) mixes.push({ id: `${window.day}:${kind}`, kind, title, subtitle, seedArtists: seeds, tracks });
    };
    add("morning", "Утро", "Спокойный старт с любимыми артистами", morningArtists, morning);
    add("focus", "Фокус", "Ровный фон для работы и учёбы", focusArtists, focus);
    add("evening", "Вечер", forgotten.length ? "Любимое и давно не звучавшее" : "Чтобы выдохнуть после дня",
      eveningArtists, [...forgotten, ...evening]);
    add("discovery", "Открытия", similarArtists.length ? `Похоже на ${similarArtists.slice(0, 2).join(", ")}` : "Новые имена рядом с вашим вкусом",
      similarArtists, discoveries);
    return {
      day: window.day,
      refreshedAt: new Date(window.start).toISOString(),
      nextRefreshAt: new Date(window.next).toISOString(),
      mixes
    };
  }

  private sweep() {
    const now = this.now();
    for (const [key, entry] of this.cache) if (entry.expiresAt <= now) this.cache.delete(key);
  }
}

type MixWindow = { day: string; start: number; next: number };

/** The mix day starts at 06:00 listener-local time. */
export function mixWindow(now: number, tzOffsetMinutes: number): MixWindow {
  const offset = Math.max(-14 * 60, Math.min(14 * 60, Math.trunc(tzOffsetMinutes))) * 60_000;
  const local = now + offset - REFRESH_HOUR * 60 * 60_000;
  const dayStartLocal = Math.floor(local / DAY) * DAY;
  const start = dayStartLocal - offset + REFRESH_HOUR * 60 * 60_000;
  return { day: new Date(dayStartLocal).toISOString().slice(0, 10), start, next: start + DAY };
}

export function normalizeTrackKey(key: string) {
  const [artist = "", title = ""] = key.split("::");
  return `${normalize(artist)}::${normalize(title)}`;
}

function diversify(items: WaveItem[], limit: number) {
  const seen = new Set<string>();
  const perArtist = new Map<string, number>();
  const result: WaveItem[] = [];
  for (const item of items) {
    const key = trackKey(item);
    const artist = normalize(item.artist);
    if (seen.has(key) || (perArtist.get(artist) ?? 0) >= 4) continue;
    seen.add(key);
    perArtist.set(artist, (perArtist.get(artist) ?? 0) + 1);
    result.push(item);
    if (result.length >= limit) break;
  }
  return result;
}

function unique(values: string[]) {
  const seen = new Set<string>();
  return values.map((value) => value.trim()).filter((value) => {
    const key = normalize(value);
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function seededIndex(seed: string, length: number) {
  if (length <= 0) return 0;
  return createHash("sha256").update(seed).digest().readUInt32BE(0) % length;
}

function rotate<T>(values: T[], by: number) {
  return values.length ? [...values.slice(by), ...values.slice(0, by)] : values;
}

/** Deterministic shuffle: the same day yields the same order on every device. */
function shuffle<T extends ProviderTrack>(values: T[], seed: string) {
  return values
    .map((value) => ({ value, rank: createHash("sha256").update(`${seed}:${value.id}`).digest().readUInt32BE(0) }))
    .sort((a, b) => a.rank - b.rank)
    .map((entry) => entry.value);
}
