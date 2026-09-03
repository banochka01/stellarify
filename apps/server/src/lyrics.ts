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

const lyricsOvhSchema = z.object({ lyrics: z.string() });
const musixmatchSchema = z.object({
  message: z.object({
    header: z.object({ status_code: z.number() }),
    body: z.record(z.string(), z.unknown()).default({})
  })
});
const compatibleLyricsSchema = z.object({
  id: z.number().int().optional(),
  title: z.string().optional(),
  artist: z.string().optional(),
  album: z.string().optional(),
  durationMs: z.number().optional(),
  instrumental: z.boolean().optional(),
  synced: z.boolean().optional(),
  syncedLyrics: z.string().optional(),
  plainLyrics: z.string().optional(),
  lyrics: z.string().optional(),
  lines: z.array(z.object({ startMs: z.number().nullable(), text: z.string() })).optional(),
  source: z.object({
    name: z.string().trim().min(1).max(80),
    url: z.string().max(2_048)
  }).optional()
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
  source: { name: string; url: string };
};

export type LyricsServiceOptions = {
  musixmatchApiKey?: string;
  lyricsOvhBaseUrl?: string | null;
  compatibleProviderUrls?: string[];
};

type FetchLike = typeof fetch;
type CacheEntry = { expiresAt: number; value: LyricsResult | null };
type ProviderAttempt = () => Promise<LyricsResult | null>;

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
  private readonly options: Required<Pick<LyricsServiceOptions, "compatibleProviderUrls">> & LyricsServiceOptions;

  constructor(
    private readonly request: FetchLike = fetch,
    private readonly now: () => number = Date.now,
    private readonly cacheMs = 6 * 60 * 60_000,
    private readonly lrclibBaseUrl = "https://lrclib.net",
    options: LyricsServiceOptions = {}
  ) {
    this.options = {
      ...options,
      lyricsOvhBaseUrl: options.lyricsOvhBaseUrl === undefined
        ? "https://api.lyrics.ovh"
        : options.lyricsOvhBaseUrl,
      compatibleProviderUrls: (options.compatibleProviderUrls ?? [])
        .map(value => value.trim())
        .filter(isHttpUrl)
        .slice(0, 4)
    };
  }

  static fromEnvironment(request: FetchLike = fetch, env = process.env) {
    return new LyricsService(request, Date.now, 6 * 60 * 60_000,
      env.LRCLIB_BASE_URL?.trim() || "https://lrclib.net", {
        musixmatchApiKey: env.MUSIXMATCH_API_KEY?.trim() || undefined,
        lyricsOvhBaseUrl: env.LYRICS_OVH_BASE_URL?.trim() || "https://api.lyrics.ovh",
        compatibleProviderUrls: (env.LYRICS_FALLBACK_URLS ?? "").split(",")
      });
  }

  async find(query: LyricsQuery): Promise<LyricsResult | null> {
    const key = [query.artist, query.title, query.album ?? "", query.durationMs ?? ""]
      .map(normalize)
      .join("|");
    const cached = this.cache.get(key);
    if (cached && cached.expiresAt > this.now()) return cached.value;
    if (cached) this.cache.delete(key);

    const errors: unknown[] = [];
    let completedProvider = false;
    try {
      const primary = await this.findLrclib(query);
      completedProvider = true;
      if (primary) {
        this.remember(key, primary);
        return primary;
      }
    } catch (error) {
      errors.push(error);
    }

    const fallbacks: ProviderAttempt[] = [];
    if (this.options.musixmatchApiKey) {
      fallbacks.push(() => this.findMusixmatch(query, this.options.musixmatchApiKey!));
    }
    for (const url of this.options.compatibleProviderUrls) {
      fallbacks.push(() => this.findCompatible(query, url));
    }
    if (this.options.lyricsOvhBaseUrl) {
      fallbacks.push(() => this.findLyricsOvh(query, this.options.lyricsOvhBaseUrl!));
    }

    const candidates: LyricsResult[] = [];
    const settled = await Promise.allSettled(fallbacks.map(attempt => attempt()));
    for (const result of settled) {
      if (result.status === "rejected") errors.push(result.reason);
      else {
        completedProvider = true;
        if (result.value) candidates.push(result.value);
      }
    }
    const value = candidates.sort((left, right) => Number(right.synced) - Number(left.synced))[0] ?? null;
    if (value || completedProvider) {
      this.remember(key, value);
      return value;
    }
    throw bestUpstreamError(errors);
  }

  private async findLrclib(query: LyricsQuery) {
    const exact = new URL("/api/get", this.lrclibBaseUrl);
    exact.searchParams.set("track_name", query.title);
    exact.searchParams.set("artist_name", query.artist);
    if (query.album?.trim()) exact.searchParams.set("album_name", query.album.trim());
    if (query.durationMs && query.durationMs > 0) {
      exact.searchParams.set("duration", String(Math.round(query.durationMs / 1_000)));
    }
    let response = await this.fetch(exact);
    let record: z.infer<typeof lyricsRecordSchema> | null = null;
    if (response.status === 404) {
      const search = new URL("/api/search", this.lrclibBaseUrl);
      search.searchParams.set("track_name", query.title);
      search.searchParams.set("artist_name", query.artist);
      response = await this.fetch(search);
      if (response.ok) record = bestMatch(z.array(lyricsRecordSchema).parse(await readJson(response)), query);
    } else if (response.ok) {
      record = lyricsRecordSchema.parse(await readJson(response));
    }
    if (!response.ok && response.status !== 404) throw upstreamError(response.status, "LRCLIB");
    return record ? mapRecord(record) : null;
  }

  private async findLyricsOvh(query: LyricsQuery, baseUrl: string) {
    const path = `/v1/${encodeURIComponent(query.artist)}/${encodeURIComponent(query.title)}`;
    const response = await this.fetch(new URL(path, baseUrl));
    if (response.status === 404) return null;
    if (!response.ok) throw upstreamError(response.status, "Lyrics.ovh");
    const body = lyricsOvhSchema.parse(await readJson(response));
    return fromPlainText(query, body.lyrics, "Lyrics.ovh", "https://lyrics.ovh");
  }

  private async findMusixmatch(query: LyricsQuery, apiKey: string) {
    const endpoint = new URL("https://api.musixmatch.com/ws/1.1/matcher.lyrics.get");
    endpoint.searchParams.set("q_track", query.title);
    endpoint.searchParams.set("q_artist", query.artist);
    endpoint.searchParams.set("apikey", apiKey);
    const response = await this.fetch(endpoint);
    if (!response.ok) throw upstreamError(response.status, "Musixmatch");
    const payload = musixmatchSchema.parse(await readJson(response));
    if (payload.message.header.status_code === 404) return null;
    if (payload.message.header.status_code !== 200) {
      throw upstreamError(payload.message.header.status_code, "Musixmatch");
    }
    const lyrics = z.object({
      lyrics_body: z.string(), instrumental: z.number().optional(), restricted: z.number().optional()
    }).safeParse(payload.message.body.lyrics);
    if (!lyrics.success || lyrics.data.restricted === 1) return null;
    return fromPlainText(query, lyrics.data.lyrics_body, "Musixmatch", "https://www.musixmatch.com",
      lyrics.data.instrumental === 1);
  }

  private async findCompatible(query: LyricsQuery, baseUrl: string) {
    const endpoint = new URL(baseUrl);
    endpoint.searchParams.set("title", query.title);
    endpoint.searchParams.set("artist", query.artist);
    if (query.album) endpoint.searchParams.set("album", query.album);
    if (query.durationMs) endpoint.searchParams.set("durationMs", String(query.durationMs));
    const response = await this.fetch(endpoint);
    if (response.status === 404) return null;
    if (!response.ok) throw upstreamError(response.status, endpoint.hostname);
    const data = compatibleLyricsSchema.parse(await readJson(response));
    const directLines = sanitizeLines(data.lines ?? []);
    const syncedLines = directLines.some(line => line.startMs !== null)
      ? directLines : parseLrc(data.syncedLyrics ?? "");
    const plainLines = plainTextLines(data.plainLyrics ?? data.lyrics ?? "");
    const lines = syncedLines.length ? syncedLines : directLines.length ? directLines : plainLines;
    if (!lines.length && !data.instrumental) return null;
    const source = data.source && isHttpUrl(data.source.url)
      ? data.source
      : { name: endpoint.hostname, url: endpoint.origin };
    return {
      id: data.id ?? syntheticId(query, endpoint.hostname),
      title: data.title ?? query.title,
      artist: data.artist ?? query.artist,
      ...(data.album ?? query.album ? { album: data.album ?? query.album } : {}),
      ...(data.durationMs ?? query.durationMs ? { durationMs: data.durationMs ?? query.durationMs } : {}),
      instrumental: data.instrumental ?? false,
      synced: data.synced ?? syncedLines.length > 0,
      lines,
      source
    };
  }

  private async fetch(url: URL) {
    try {
      return await this.request(url, {
        headers: { accept: "application/json", "user-agent": "Resonance/1.3 (https://music.webcordes.ru)" },
        signal: AbortSignal.timeout(6_000)
      });
    } catch (error) {
      if (error instanceof DOMException && error.name === "TimeoutError") {
        throw new LyricsError("UPSTREAM_TIMEOUT", `Lyrics provider ${url.hostname} timed out`, 504, { cause: error });
      }
      throw new LyricsError("UPSTREAM_ERROR", `Lyrics provider ${url.hostname} failed`, 502, { cause: error });
    }
  }

  private remember(key: string, value: LyricsResult | null) {
    if (this.cache.size >= 500) this.cache.delete(this.cache.keys().next().value ?? "");
    this.cache.set(key, {
      expiresAt: this.now() + (value ? this.cacheMs : Math.min(this.cacheMs, 15 * 60_000)), value
    });
  }
}

function upstreamError(status: number, provider: string) {
  return status === 429
    ? new LyricsError("UPSTREAM_RATE_LIMITED", `${provider} rate limited the request`, 503)
    : new LyricsError("UPSTREAM_ERROR", `${provider} returned HTTP ${status}`, 502);
}

function bestUpstreamError(errors: unknown[]) {
  const known = errors.filter((error): error is LyricsError => error instanceof LyricsError);
  return known.find(error => error.code === "UPSTREAM_RATE_LIMITED")
    ?? known.find(error => error.code === "UPSTREAM_TIMEOUT")
    ?? known[0]
    ?? new LyricsError("UPSTREAM_ERROR", "Every lyrics provider failed", 502);
}

function mapRecord(record: z.infer<typeof lyricsRecordSchema>): LyricsResult {
  const syncedLines = parseLrc(record.syncedLyrics ?? "");
  const plainLines = plainTextLines(record.plainLyrics ?? "");
  return {
    id: record.id, title: record.trackName, artist: record.artistName,
    ...(record.albumName ? { album: record.albumName } : {}),
    ...(record.duration ? { durationMs: Math.round(record.duration * 1_000) } : {}),
    instrumental: record.instrumental,
    synced: syncedLines.length > 0,
    lines: syncedLines.length > 0 ? syncedLines : plainLines,
    source: { name: "LRCLIB", url: "https://lrclib.net" }
  };
}

function fromPlainText(
  query: LyricsQuery, input: string, sourceName: string, sourceUrl: string, instrumental = false
): LyricsResult | null {
  const lines = plainTextLines(input);
  if (!lines.length && !instrumental) return null;
  return {
    id: syntheticId(query, sourceName), title: query.title, artist: query.artist,
    ...(query.album ? { album: query.album } : {}),
    ...(query.durationMs ? { durationMs: query.durationMs } : {}),
    instrumental, synced: false, lines, source: { name: sourceName, url: sourceUrl }
  };
}

function plainTextLines(input: string): LyricLine[] {
  return sanitizeLines(input.split(/\r?\n/).map(text => ({ startMs: null, text })));
}

function sanitizeLines(lines: LyricLine[]) {
  return lines
    .map(line => ({ startMs: line.startMs, text: line.text.replace(/\0/g, "").trim().slice(0, 1_000) }))
    .filter(line => line.text.length > 0)
    .slice(0, 2_500);
}

function syntheticId(query: LyricsQuery, provider: string) {
  let hash = 2166136261;
  for (const code of `${provider}|${query.artist}|${query.title}`) {
    hash ^= code.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function isHttpUrl(value: string) {
  try {
    const protocol = new URL(value).protocol;
    return protocol === "https:" || protocol === "http:";
  } catch {
    return false;
  }
}

async function readJson(response: Response) {
  const limit = 512 * 1_024;
  const declared = Number(response.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > limit) {
    throw new LyricsError("UPSTREAM_ERROR", "Lyrics provider response is too large", 502);
  }
  if (!response.body) return JSON.parse(await response.text()) as unknown;
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) {
      await reader.cancel();
      throw new LyricsError("UPSTREAM_ERROR", "Lyrics provider response is too large", 502);
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return JSON.parse(new TextDecoder().decode(bytes)) as unknown;
}

export function parseLrc(input: string): LyricLine[] {
  const output: Array<LyricLine & { order: number }> = [];
  let offset = 0;
  let order = 0;
  for (const raw of input.split(/\r?\n/)) {
    const offsetMatch = /^\[offset:([+-]?\d+)\]$/i.exec(raw.trim());
    if (offsetMatch) { offset = Number(offsetMatch[1]); continue; }
    const stamps = [...raw.matchAll(/\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]/g)];
    if (!stamps.length) continue;
    const text = raw.replace(/\[[^\]]+\]/g, "").trim();
    for (const stamp of stamps) {
      const fraction = stamp[3] ?? "0";
      const fractionMs = fraction.length === 1 ? Number(fraction) * 100
        : fraction.length === 2 ? Number(fraction) * 10 : Number(fraction.slice(0, 3));
      const startMs = Math.max(0,
        Number(stamp[1]) * 60_000 + Number(stamp[2]) * 1_000 + fractionMs + offset);
      output.push({ startMs, text: text.slice(0, 1_000), order: order++ });
    }
  }
  return output
    .sort((left, right) => (left.startMs ?? 0) - (right.startMs ?? 0) || left.order - right.order)
    .slice(0, 2_500)
    .map(({ startMs, text }) => ({ startMs, text }));
}

function bestMatch(records: Array<z.infer<typeof lyricsRecordSchema>>, query: LyricsQuery) {
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
