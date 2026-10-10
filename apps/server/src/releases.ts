import type { ProviderAccess, ProviderTrack } from "./provider-gateway.js";
import { normalize, trackKey, type WaveItem, type WaveProviderName } from "./wave.js";

export interface Release {
  id: string;
  provider: "spotify";
  title: string;
  artist: string;
  releaseDate: string;
  kind: "album" | "single" | "compilation";
  trackCount?: number;
  artworkUrl?: string;
  externalUrl: string;
}

export interface ReleaseSource {
  readonly configured: boolean;
  artistReleases(artist: string, limit?: number): Promise<Omit<Release, "provider">[]>;
}

type Search = (provider: WaveProviderName, query: string, limit: number, access?: ProviderAccess) => Promise<ProviderTrack[]>;

type ArtistEntry = { releases: Release[]; fetchedAt: number; lastRequestedAt: number };

const DAY = 24 * 60 * 60_000;

/**
 * Tracks new releases of artists listeners follow. Every feed request
 * registers its artists; a background poll keeps their catalogs warm so the
 * Home row answers from cache instead of fanning out to the provider.
 */
export class ReleaseService {
  private readonly artists = new Map<string, ArtistEntry & { name: string }>();
  private readonly inflight = new Map<string, Promise<Release[]>>();
  private readonly freshWeekCache = new Map<string, { expiresAt: number; value: FreshWeek }>();
  private timer?: NodeJS.Timeout;

  constructor(
    private readonly source: ReleaseSource,
    private readonly search: Search,
    private readonly options: { ttlMs?: number; maxArtists?: number } = {},
    private readonly now: () => number = Date.now
  ) {}

  get available() {
    return this.source.configured;
  }

  private get ttlMs() { return this.options.ttlMs ?? 6 * 60 * 60_000; }
  private get maxArtists() { return this.options.maxArtists ?? 2000; }

  /** Background refresh of tracked artists. The timer never keeps the process alive. */
  startPolling(intervalMs = 3 * 60 * 60_000) {
    if (this.timer || !this.available) return;
    this.timer = setInterval(() => void this.poll().catch(() => undefined), intervalMs);
    this.timer.unref?.();
  }

  stopPolling() {
    if (this.timer) clearInterval(this.timer);
    this.timer = undefined;
  }

  async poll(concurrency = 4) {
    const now = this.now();
    // Artists nobody asked about for two weeks stop being polled.
    for (const [key, entry] of this.artists) if (now - entry.lastRequestedAt > 14 * DAY) this.artists.delete(key);
    const stale = [...this.artists.entries()].filter(([, entry]) => now - entry.fetchedAt >= this.ttlMs);
    for (let index = 0; index < stale.length; index += concurrency) {
      await Promise.all(stale.slice(index, index + concurrency).map(([, entry]) => this.refresh(entry.name)));
    }
    return stale.length;
  }

  async feed(artists: string[], days = 30): Promise<{ available: boolean; releases: Release[] }> {
    if (!this.available) return { available: false, releases: [] };
    const names = uniqueArtists(artists).slice(0, 40);
    const now = this.now();
    const lists = await Promise.all(names.map(async (name) => {
      const key = normalize(name);
      const entry = this.artists.get(key);
      if (entry) entry.lastRequestedAt = now;
      if (entry && now - entry.fetchedAt < this.ttlMs) return entry.releases;
      return this.refresh(name);
    }));
    const since = now - days * DAY;
    const seen = new Set<string>();
    const releases = lists.flat()
      .filter((release) => releaseTime(release.releaseDate) >= since && releaseTime(release.releaseDate) <= now + DAY)
      .filter((release) => !seen.has(release.id) && Boolean(seen.add(release.id)))
      .sort((a, b) => releaseTime(b.releaseDate) - releaseTime(a.releaseDate));
    return { available: true, releases: releases.slice(0, 60) };
  }

  /** "Свежее за неделю": playable tracks from releases of the week ending on the latest Friday. */
  async freshWeek(artists: string[], providers: WaveProviderName[], access: Partial<Record<WaveProviderName, ProviderAccess>> = {}): Promise<FreshWeek> {
    const friday = lastFriday(this.now());
    const names = uniqueArtists(artists).slice(0, 40);
    const cacheKey = `${friday}:${providers.join(",")}:${names.map(normalize).sort().join("|")}`;
    const cached = this.freshWeekCache.get(cacheKey);
    if (cached && cached.expiresAt > this.now()) return cached.value;
    const { available, releases } = await this.feed(names, 14);
    const window = releases.filter((release) => {
      const time = releaseTime(release.releaseDate);
      return time >= friday - 7 * DAY && time <= this.now();
    }).slice(0, 15);
    const searchProviders = providers.filter((provider) => provider !== "spotify").slice(0, 2);
    const found = await Promise.all(window.flatMap((release) => searchProviders.map(async (provider) => {
      try {
        const tracks = await this.search(provider, `${primaryArtist(release.artist)} ${release.title}`, 4, access[provider]);
        const artist = normalize(primaryArtist(release.artist));
        return tracks
          .filter((track) => normalize(track.artist).includes(artist))
          .slice(0, release.kind === "single" ? 1 : 3)
          .map((track, rank): WaveItem => ({ ...track, provider, lane: "safe", score: 1 - rank * .05, reason: `Новое: ${release.title}` }));
      } catch {
        return [];
      }
    })));
    const seen = new Set<string>();
    const tracks = found.flat().filter((track) => {
      const key = trackKey(track);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    }).slice(0, 40);
    const value: FreshWeek = {
      available,
      weekOf: new Date(friday).toISOString().slice(0, 10),
      nextRefreshAt: new Date(friday + 7 * DAY).toISOString(),
      releases: window,
      tracks
    };
    if (this.freshWeekCache.size >= 2000) this.freshWeekCache.clear();
    this.freshWeekCache.set(cacheKey, { expiresAt: Math.min(friday + 7 * DAY, this.now() + this.ttlMs), value });
    return value;
  }

  private refresh(name: string): Promise<Release[]> {
    const key = normalize(name);
    const running = this.inflight.get(key);
    if (running) return running;
    const task = this.source.artistReleases(name, 10).then((items) => {
      const releases = items
        .filter((item) => normalize(item.artist).includes(key))
        .map((item): Release => ({ ...item, provider: "spotify" }));
      this.remember(name, releases);
      return releases;
    }).catch(() => {
      // Keep the last good answer; retry after the TTL instead of hammering the provider.
      const previous = this.artists.get(key)?.releases ?? [];
      this.remember(name, previous);
      return previous;
    }).finally(() => this.inflight.delete(key));
    this.inflight.set(key, task);
    return task;
  }

  private remember(name: string, releases: Release[]) {
    const key = normalize(name);
    if (!this.artists.has(key) && this.artists.size >= this.maxArtists) {
      const oldest = [...this.artists.entries()].sort((a, b) => a[1].lastRequestedAt - b[1].lastRequestedAt)[0];
      if (oldest) this.artists.delete(oldest[0]);
    }
    const now = this.now();
    this.artists.set(key, { name, releases, fetchedAt: now, lastRequestedAt: this.artists.get(key)?.lastRequestedAt ?? now });
  }
}

export interface FreshWeek {
  available: boolean;
  weekOf: string;
  nextRefreshAt: string;
  releases: Release[];
  tracks: WaveItem[];
}

/** UTC midnight of the latest Friday (new music day) at or before `now`. */
export function lastFriday(now: number) {
  const date = new Date(now);
  const midnight = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
  const back = (date.getUTCDay() - 5 + 7) % 7;
  return midnight - back * DAY;
}

export function releaseTime(value: string) {
  // Spotify precision can be year ("2024"), month ("2024-05") or day.
  const padded = value.length === 4 ? `${value}-01-01` : value.length === 7 ? `${value}-01` : value;
  const time = Date.parse(`${padded}T00:00:00Z`);
  return Number.isFinite(time) ? time : 0;
}

function primaryArtist(value: string) {
  return value.split(",")[0]?.trim() ?? value;
}

function uniqueArtists(values: string[]) {
  const seen = new Set<string>();
  return values.map((value) => value.trim()).filter((value) => {
    const key = normalize(value);
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
