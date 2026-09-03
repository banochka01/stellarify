import { z } from "zod";

const lyricsRecordSchema = z.object({
  id: z.number().int().nonnegative(),
  trackName: z.string(),
  artistName: z.string(),
  albumName: z.string().nullable().optional(),
  duration: z.number().nonnegative().nullable().optional(),
  instrumental: z.boolean().default(false),
  plainLyrics: z.string().nullable().optional(),
  syncedLyrics: z.string().nullable().optional()
});

export type LyricsQuery = {
  title: string;
  artist: string;
  album?: string;
  durationMs?: number;
};

export type LyricLine = { startMs: number | null; text: string };

export type LyricsResult = {
  id: number;
  title: string;
  artist: string;
  album?: string;
  durationMs?: number;
  instrumental: boolean;
  synced: boolean;
  lines: LyricLine[];
  source: { name: "LRCLIB"; url: string };
};

type FetchLike = typeof fetch;
type CacheEntry = { expiresAt: number; value: LyricsResult | null };

export class LyricsError extends Error {
  constructor(
    readonly code: "UPSTREAM_ERROR" | "UPSTREAM_TIMEOUT" | "UPSTREAM_RATE_LIMITED",
    message: string,
    readonly status: number,
    options?: ErrorOptions
  ) {
    super(message, options);
    this.name = "LyricsError";
  }
}

export class LyricsService {
  private readonly cache = new Map<string, CacheEntry>();

  constructor(
    private readonly request: FetchLike = fetch,
    private readonly now: () => number = Date.now,
    private readonly cacheMs = 6 * 60 * 60_000,
    private readonly baseUrl = "https://lrclib.net"
  ) {}

  async find(query: LyricsQuery): Promise<LyricsResult | null> {
    const key = [query.artist, query.title, query.album ?? "", query.durationMs ?? ""]
      .map(normalize)
      .join("|");
    const cached = this.cache.get(key);
    if (cached && cached.expiresAt > this.now()) return cached.value;
    if (cached) this.cache.delete(key);

    try {
      const exact = new URL("/api/get", this.baseUrl);
      exact.searchParams.set("track_name", query.title);
      exact.searchParams.set("artist_name", query.artist);
      if (query.album?.trim()) exact.searchParams.set("album_name", query.album.trim());
      if (query.durationMs && query.durationMs > 0) {
        exact.searchParams.set("duration", String(Math.round(query.durationMs / 1_000)));
      }
      let response = await this.fetch(exact);
      let record: z.infer<typeof lyricsRecordSchema> | null = null;
      if (response.status === 404) {
        const search = new URL("/api/search", this.baseUrl);
        search.searchParams.set("track_name", query.title);
        search.searchParams.set("artist_name", query.artist);
        response = await this.fetch(search);
        if (response.ok) {
          const records = z.array(lyricsRecordSchema).parse(await response.json());
          record = bestMatch(records, query);
        }
      } else if (response.ok) {
        record = lyricsRecordSchema.parse(await response.json());
      }
      if (!response.ok && response.status !== 404) throw upstreamError(response.status);
      const value = record ? mapRecord(record) : null;
      this.remember(key, value);
      return value;
    } catch (error) {
      if (error instanceof LyricsError) throw error;
      if (error instanceof DOMException && error.name === "TimeoutError") {
        throw new LyricsError("UPSTREAM_TIMEOUT", "Lyrics provider timed out", 504, { cause: error });
      }
      throw new LyricsError("UPSTREAM_ERROR", "Lyrics provider returned an invalid response", 502, { cause: error });
    }
  }

  private fetch(url: URL) {
    return this.request(url, {
      headers: {
        accept: "application/json",
        "user-agent": "Resonance/1.1 (https://music.webcordes.ru)"
      },
      signal: AbortSignal.timeout(8_000)
    });
  }

  private remember(key: string, value: LyricsResult | null) {
    if (this.cache.size >= 500) this.cache.delete(this.cache.keys().next().value ?? "");
    this.cache.set(key, {
      expiresAt: this.now() + (value ? this.cacheMs : Math.min(this.cacheMs, 15 * 60_000)),
      value
    });
  }
}

function upstreamError(status: number) {
  return status === 429
    ? new LyricsError("UPSTREAM_RATE_LIMITED", "Lyrics provider rate limited the request", 503)
    : new LyricsError("UPSTREAM_ERROR", `Lyrics provider returned HTTP ${status}`, 502);
}

function mapRecord(record: z.infer<typeof lyricsRecordSchema>): LyricsResult {
  const syncedLines = parseLrc(record.syncedLyrics ?? "");
  const plainLines = (record.plainLyrics ?? "")
    .split(/\r?\n/)
    .map(text => ({ startMs: null, text: text.trim() }))
    .filter(line => line.text.length > 0);
  return {
    id: record.id,
    title: record.trackName,
    artist: record.artistName,
    ...(record.albumName ? { album: record.albumName } : {}),
    ...(record.duration ? { durationMs: Math.round(record.duration * 1_000) } : {}),
    instrumental: record.instrumental,
    synced: syncedLines.length > 0,
    lines: syncedLines.length > 0 ? syncedLines : plainLines,
    source: { name: "LRCLIB", url: "https://lrclib.net" }
  };
}

export function parseLrc(input: string): LyricLine[] {
  const output: Array<LyricLine & { order: number }> = [];
  let offset = 0;
  let order = 0;
  for (const raw of input.split(/\r?\n/)) {
    const offsetMatch = /^\[offset:([+-]?\d+)\]$/i.exec(raw.trim());
    if (offsetMatch) {
      offset = Number(offsetMatch[1]);
      continue;
    }
    const stamps = [...raw.matchAll(/\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]/g)];
    if (!stamps.length) continue;
    const text = raw.replace(/\[[^\]]+\]/g, "").trim();
    for (const stamp of stamps) {
      const fraction = stamp[3] ?? "0";
      const fractionMs = fraction.length === 1
        ? Number(fraction) * 100
        : fraction.length === 2
        ? Number(fraction) * 10
        : Number(fraction.slice(0, 3));
      const startMs = Math.max(0, Number(stamp[1]) * 60_000 + Number(stamp[2]) * 1_000 + fractionMs + offset);
      output.push({ startMs, text, order: order++ });
    }
  }
  return output
    .sort((left, right) => (left.startMs ?? 0) - (right.startMs ?? 0) || left.order - right.order)
    .map(({ startMs, text }) => ({ startMs, text }));
}

function bestMatch(
  records: Array<z.infer<typeof lyricsRecordSchema>>,
  query: LyricsQuery
) {
  const title = normalize(query.title);
  const artist = normalize(query.artist);
  const ranked = [...records].sort((left, right) => score(right) - score(left));
  const candidate = ranked[0];
  return candidate && score(candidate) >= 6 ? candidate : null;

  function score(record: z.infer<typeof lyricsRecordSchema>) {
    let value = 0;
    if (normalize(record.trackName) === title) value += 4;
    if (normalize(record.artistName) === artist) value += 4;
    if (record.syncedLyrics?.trim()) value += 2;
    if (query.durationMs && record.duration) {
      const delta = Math.abs(query.durationMs - record.duration * 1_000);
      if (delta <= 3_000) value += 2;
      else if (delta <= 10_000) value += 1;
    }
    return value;
  }
}

function normalize(value: string | number) {
  return String(value).trim().toLowerCase().replace(/\s+/g, " ");
}
