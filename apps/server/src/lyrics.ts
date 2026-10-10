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

export type LyricWord = { startMs: number; text: string };
export type LyricLine = { startMs: number | null; text: string; words?: LyricWord[] };
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
export type ProviderAttempt = () => Promise<LyricsResult | null>;

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
        .slice(0, 12)
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

  async find(query: LyricsQuery, extraAttempts: ProviderAttempt[] = []): Promise<LyricsResult | null> {
    const key = [query.artist, query.title, query.album ?? "", query.durationMs ?? ""]
      .map(normalize)
      .join("|");
    const useSharedCache = extraAttempts.length === 0;
    const cached = useSharedCache ? this.cache.get(key) : undefined;
    if (cached && cached.expiresAt > this.now()) return cached.value;
    if (cached) this.cache.delete(key);

    const errors: unknown[] = [];
    let completedProvider = false;
    try {
      const primary = await this.findLrclib(query);
      completedProvider = true;
      if (primary) {
        if (useSharedCache) this.remember(key, primary);
        return primary;
      }
    } catch (error) {
      errors.push(error);
    }

    const fallbacks: ProviderAttempt[] = [];
    fallbacks.push(...extraAttempts.slice(0, 4));
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
      if (useSharedCache) this.remember(key, value);
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
    const request = async (method: "matcher.subtitle.get" | "matcher.lyrics.get") => {
      const endpoint = new URL(`https://api.musixmatch.com/ws/1.1/${method}`);
      endpoint.searchParams.set("q_track", query.title);
      endpoint.searchParams.set("q_artist", query.artist);
      endpoint.searchParams.set("apikey", apiKey);
      if (method === "matcher.subtitle.get") {
        endpoint.searchParams.set("subtitle_format", "lrc");
        if (query.durationMs) {
          endpoint.searchParams.set("f_subtitle_length", String(Math.round(query.durationMs / 1_000)));
          endpoint.searchParams.set("f_subtitle_length_max_deviation", "4");
        }
      }
      const response = await this.fetch(endpoint);
      if (!response.ok) throw upstreamError(response.status, "Musixmatch");
      return musixmatchSchema.parse(await readJson(response));
    };

    const subtitlePayload = await request("matcher.subtitle.get");
    if (subtitlePayload.message.header.status_code === 200) {
      const subtitle = z.object({ subtitle_body: z.string(), restricted: z.number().optional() })
        .safeParse(subtitlePayload.message.body.subtitle);
      if (subtitle.success && subtitle.data.restricted !== 1) {
        const result = lyricsResultFromText(query, subtitle.data.subtitle_body,
          "Musixmatch", "https://www.musixmatch.com", false, true);
        if (result?.lines.length) return result;
      }
    } else if (subtitlePayload.message.header.status_code !== 404) {
      throw upstreamError(subtitlePayload.message.header.status_code, "Musixmatch");
    }

    const payload = await request("matcher.lyrics.get");
    if (payload.message.header.status_code === 404) return null;
    if (payload.message.header.status_code !== 200) {
      throw upstreamError(payload.message.header.status_code, "Musixmatch");
    }
    const lyrics = z.object({
      lyrics_body: z.string(), instrumental: z.number().optional(), restricted: z.number().optional()
    }).safeParse(payload.message.body.lyrics);
    if (!lyrics.success || lyrics.data.restricted === 1) return null;
    return lyricsResultFromText(query, lyrics.data.lyrics_body, "Musixmatch", "https://www.musixmatch.com",
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
        headers: { accept: "application/json", "user-agent": "Resonance/3.3 (https://music.webcordes.ru)" },
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
  return lyricsResultFromText(query, input, sourceName, sourceUrl, instrumental);
}

export function lyricsResultFromText(
  query: LyricsQuery,
  input: string,
  sourceName: string,
  sourceUrl: string,
  instrumental = false,
  synchronized = false
): LyricsResult | null {
  const syncedLines = synchronized ? parseLrc(input) : [];
  const lines = syncedLines.length ? syncedLines : plainTextLines(input);
  if (!lines.length && !instrumental) return null;
  return {
    id: syntheticId(query, sourceName), title: query.title, artist: query.artist,
    ...(query.album ? { album: query.album } : {}),
    ...(query.durationMs ? { durationMs: query.durationMs } : {}),
    instrumental, synced: syncedLines.length > 0, lines, source: { name: sourceName, url: sourceUrl }
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
    const body = raw.replace(/\[[^\]]+\]/g, "");
    const text = body.replace(/<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>/g, "").replace(/\s+/g, " ").trim();
    const words = parseWordStamps(body, offset);
    for (const stamp of stamps) {
      const startMs = Math.max(0, stampMs(stamp[1]!, stamp[2]!, stamp[3]) + offset);
      output.push({
        startMs, text: text.slice(0, 1_000), order: order++,
        ...(words.length >= 2 && stamps.length === 1 ? { words } : {})
      });
    }
  }
  return output
    .sort((left, right) => (left.startMs ?? 0) - (right.startMs ?? 0) || left.order - right.order)
    .slice(0, 2_500)
    .map(({ order: _order, ...line }) => line);
}

function stampMs(minutes: string, seconds: string, fraction = "0") {
  const fractionMs = fraction.length === 1 ? Number(fraction) * 100
    : fraction.length === 2 ? Number(fraction) * 10 : Number(fraction.slice(0, 3));
  return Number(minutes) * 60_000 + Number(seconds) * 1_000 + fractionMs;
}

/** Enhanced LRC (A2): `<mm:ss.xx>word <mm:ss.xx>word`. Returns [] without word stamps. */
function parseWordStamps(body: string, offset: number): LyricWord[] {
  const pattern = /<(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?>([^<]*)/g;
  const words: LyricWord[] = [];
  for (const match of body.matchAll(pattern)) {
    const text = match[4]!.replace(/\s+/g, " ");
    if (!text.trim()) continue;
    words.push({ startMs: Math.max(0, stampMs(match[1]!, match[2]!, match[3]) + offset), text });
  }
  if (words.length) {
    words[0]!.text = words[0]!.text.trimStart();
    words[words.length - 1]!.text = words[words.length - 1]!.text.trimEnd();
  }
  return words.slice(0, 200);
}

export type TranslationOptions = { baseUrl?: string; apiKey?: string };

/**
 * Optional line translation through a LibreTranslate-compatible endpoint the
 * operator already runs (LYRICS_TRANSLATE_URL). Without it the feature is
 * reported as unavailable and the client hides it. No paid provider is used.
 */
export class LyricsTranslator {
  private readonly cache = new Map<string, string[]>();

  constructor(
    private readonly options: TranslationOptions,
    private readonly request: FetchLike = fetch
  ) {}

  static fromEnvironment(request: FetchLike = fetch, env: NodeJS.ProcessEnv = process.env) {
    const baseUrl = env.LYRICS_TRANSLATE_URL?.trim();
    const apiKey = env.LYRICS_TRANSLATE_KEY?.trim();
    return new LyricsTranslator({
      ...(baseUrl && isHttpUrl(baseUrl) ? { baseUrl } : {}),
      ...(apiKey ? { apiKey } : {})
    }, request);
  }

  get available() { return Boolean(this.options.baseUrl); }

  async translate(lines: string[], target: string): Promise<string[]> {
    if (!this.options.baseUrl) {
      throw new LyricsError("UPSTREAM_ERROR", "Translation is not configured", 503);
    }
    const input = lines.slice(0, 400).map(line => line.slice(0, 500));
    const key = `${target}|${input.join("\n")}`;
    const cached = this.cache.get(key);
    if (cached) return cached;
    const base = this.options.baseUrl.endsWith("/") ? this.options.baseUrl : `${this.options.baseUrl}/`;
    let response: Response;
    try {
      response = await this.request(new URL("translate", base), {
        method: "POST",
        headers: { "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({
          q: input, source: "auto", target, format: "text",
          ...(this.options.apiKey ? { api_key: this.options.apiKey } : {})
        }),
        signal: AbortSignal.timeout(12_000)
      });
    } catch (error) {
      throw new LyricsError("UPSTREAM_TIMEOUT", "Translation provider failed", 504, { cause: error });
    }
    if (!response.ok) throw upstreamError(response.status, "Translation");
    const body = z.object({ translatedText: z.union([z.string(), z.array(z.string())]) })
      .parse(await readJson(response));
    const output = Array.isArray(body.translatedText) ? body.translatedText : body.translatedText.split("\n");
    const result = input.map((_, index) => (output[index] ?? "").trim());
    if (this.cache.size >= 200) this.cache.delete(this.cache.keys().next().value ?? "");
    this.cache.set(key, result);
    return result;
  }
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
