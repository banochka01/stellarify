import { readFileSync } from "node:fs";
import { ProxyAgent, type Dispatcher } from "undici";
import { Router, type Request } from "express";
import { z } from "zod";
import { normalizeProxyUrl } from "./soundcloud.js";
import { ClipOffsetStore, isYoutubeId, youtubeEmbedPage, youtubeId } from "./clip-embed.js";
import { invidiousVideos, songLinkVideos, YoutubeWebSearch, type JsonFetcher, type VideoHit } from "./clip-sources.js";

const httpsUrl = z.string().url().max(2048).refine((value) => {
  const url = new URL(value);
  return url.protocol === "https:" && !url.username && !url.password;
});
export const clipSchema = z.object({
  id: z.string().min(1).max(200),
  title: z.string().min(1).max(200),
  artist: z.string().max(200).default(""),
  url: httpsUrl.optional(),
  playback: z.enum(["direct", "embed", "external"]).default("direct"),
  embed: z.object({ provider: z.literal("youtube"), id: z.string().regex(/^[A-Za-z0-9_-]{11}$/) }).optional(),
  kind: z.enum(["musicVideo", "preview", "ambient"]),
  source: z.string().min(1).max(100),
  sourceUrl: httpsUrl,
  offsetMs: z.number().int().min(-600000).max(600000).default(0)
}).superRefine((clip, context) => {
  if (clip.playback === "direct" && !clip.url) {
    context.addIssue({ code: "custom", path: ["url"], message: "Direct clips require a media URL" });
  }
  if (clip.playback === "embed" && !clip.embed) {
    context.addIssue({ code: "custom", path: ["embed"], message: "Embedded clips require an embed reference" });
  }
});
export type Clip = z.infer<typeof clipSchema>;
export type ClipQuery = { title: string; artist: string; yandexId?: string };
export type ClipSourceOptions = {
  appleCountries?: string[];
  dailymotion?: boolean;
  musicBrainz?: boolean;
  audioDbKey?: string;
  youtubeKey?: string;
  songLinkKey?: string;
  invidiousUrls?: string[];
  /** Outbound proxy for YouTube and Invidious, which the host cannot reach directly. */
  youtubeDispatcher?: Dispatcher;
  youtubeWeb?: YoutubeWebSearch;
  vimeoToken?: string;
};
const catalogSchema = z.object({ clips: z.array(clipSchema).max(2000) });
const querySchema = z.object({
  title: z.string().trim().min(1).max(200),
  artist: z.string().trim().min(1).max(200),
  yandexId: z.string().trim().regex(/^\d+(?::\d+)?$/).optional(),
  embed: z.string().trim().max(60).optional()
});
const offsetSchema = z.object({
  title: z.string().trim().min(1).max(200),
  artist: z.string().trim().min(1).max(200),
  clipId: z.string().min(1).max(200),
  offsetMs: z.number().int().min(-600000).max(600000)
});
export const clipTrackKey = (title: string, artist: string) => JSON.stringify([normalize(title), normalize(artist)]);
const normalize = (value: string) => transliterate(value.normalize("NFKC").toLocaleLowerCase())
  .replace(/\([^)]*(?:official|video|audio|feat\.?|ft\.?).*?\)/giu, " ")
  .replace(/\[[^\]]*(?:official|video|audio|feat\.?|ft\.?).*?\]/giu, " ")
  .replace(/\b(?:official\s+)?(?:music\s+)?video\b/giu, " ")
  .replace(/[^\p{L}\p{N}]+/gu, " ").trim();

export class ClipService {
  private readonly cache = new Map<string, { expires: number; clips: Clip[] }>();
  private readonly pending = new Map<string, Promise<Clip[]>>();
  constructor(
    private readonly catalog: Clip[] = [],
    private readonly endpoints: string[] = [],
    private readonly pexelsKey = "",
    private readonly request: typeof fetch = fetch,
    private readonly fallback: Clip[] = [],
    private readonly sources: ClipSourceOptions = {}
  ) {
    endpoints.forEach((url) => httpsUrl.parse(url));
  }

  static fromEnvironment(request: typeof fetch = fetch, env = process.env) {
    const catalog = env.CLIP_CATALOG_PATH
      ? catalogSchema.parse(JSON.parse(readFileSync(env.CLIP_CATALOG_PATH, "utf8"))).clips : [];
    const appleCountries = (env.CLIP_APPLE_COUNTRIES || "ru,us,gb")
      .split(",").map((country) => country.trim().toLowerCase())
      .filter((country) => /^[a-z]{2}$/.test(country)).slice(0, 8);
    return new ClipService(catalog,
      (env.CLIP_PROVIDER_URLS || "").split(",").map((url) => url.trim()).filter(Boolean).slice(0, 12),
      env.PEXELS_API_KEY || "", request,
      [],
      {
        appleCountries: env.CLIP_APPLE_ENABLED === "false" ? [] : appleCountries,
        dailymotion: env.CLIP_DAILYMOTION_ENABLED !== "false",
        musicBrainz: env.CLIP_MUSICBRAINZ_ENABLED !== "false",
        audioDbKey: env.AUDIODB_API_KEY || "",
        youtubeKey: env.YOUTUBE_API_KEY || "",
        songLinkKey: env.CLIP_SONGLINK_KEY || "",
        youtubeDispatcher: youtubeProxy(env),
        invidiousUrls: (env.CLIP_INVIDIOUS_URLS || "").split(",").map((url) => url.trim()).filter(Boolean)
          .filter((url) => httpsUrl.safeParse(url).success).slice(0, 6),
        youtubeWeb: youtubeWebFromEnvironment(env)?.withDispatcher(youtubeProxy(env)),
        vimeoToken: env.VIMEO_ACCESS_TOKEN || ""
      });
  }

  async find(title: string, artist: string): Promise<Clip[]> {
    const key = JSON.stringify([normalize(title), normalize(artist)]);
    const cached = this.cache.get(key);
    if (cached && cached.expires > Date.now()) return cached.clips;
    const existing = this.pending.get(key);
    if (existing) return existing;
    if (this.pending.size >= 32) throw new Error("Clip provider busy");
    const task = this.resolve(title, artist).then((clips) => {
      if (this.cache.size >= 500) this.cache.delete(this.cache.keys().next().value!);
      this.cache.set(key, { expires: Date.now() + 30 * 60_000, clips });
      return clips;
    }).finally(() => this.pending.delete(key));
    this.pending.set(key, task);
    return task;
  }

  merge(title: string, artist: string, ...groups: Clip[][]) {
    const matches = (clip: Clip) => clip.kind === "ambient" || musicMatch(clip.title, clip.artist, title, artist) >= 8.5;
    const valid = groups.flat().flatMap((candidate) => {
      const parsed = clipSchema.safeParse(candidate);
      return parsed.success && matches(parsed.data) ? [parsed.data] : [];
    });
    return [...new Map(valid.sort((left, right) => clipRank(left) - clipRank(right))
      .map((clip) => [`${clip.url ?? clip.sourceUrl}|${clip.id}`, clip])).values()].slice(0, 16);
  }

  private readonly fetchJson: JsonFetcher = (url, init) => this.json(url, init?.headers, init);

  private async json(url: URL, headers?: Record<string, string>, init?: { method?: "GET" | "POST"; body?: string; dispatcher?: Dispatcher }) {
    const response = await this.request(url, {
      method: init?.method ?? "GET", body: init?.body,
      ...(init?.dispatcher ? { dispatcher: init.dispatcher } as RequestInit : {}),
      headers: { accept: "application/json", "user-agent": "Resonance/3.3 (https://music.webcordes.ru)", ...headers },
      redirect: "error", signal: AbortSignal.timeout(6000)
    });
    if (!response.ok) throw new Error("Clip source unavailable");
    const reader = response.body?.getReader();
    if (!reader) throw new Error("Empty clip response");
    const chunks: Uint8Array[] = [];
    let size = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.length;
        if (size > 1024 * 1024) throw new Error("Clip response too large");
        chunks.push(value);
      }
    } finally { await reader.cancel(); }
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  }

  private async resolve(title: string, artist: string) {
    const matches = (clip: Clip) => clip.kind === "ambient" || musicMatch(clip.title, clip.artist, title, artist) >= 8.5;
    const local = this.catalog.filter(matches);
    const attempts: Array<Promise<Clip[]>> = this.endpoints.map(async (endpoint) => {
      const url = new URL(endpoint);
      url.searchParams.set("title", title);
      url.searchParams.set("artist", artist);
      return catalogSchema.parse(await this.json(url)).clips.filter(matches);
    });
    if (this.sources.appleCountries?.length) attempts.push(this.apple(title, artist));
    if (this.sources.dailymotion) attempts.push(this.dailymotion(title, artist));
    if (this.sources.musicBrainz) attempts.push(this.musicBrainz(title, artist));
    if (this.sources.audioDbKey) attempts.push(this.audioDb(title, artist, this.sources.audioDbKey));
    if (this.sources.youtubeKey) attempts.push(this.youtube(title, artist, this.sources.youtubeKey));
    if (this.sources.vimeoToken) attempts.push(this.vimeo(title, artist, this.sources.vimeoToken));
    if (this.sources.songLinkKey) {
      attempts.push(songLinkVideos(this.fetchJson, this.sources.songLinkKey, title, artist, undefined, this.sources.appleCountries?.[0])
        .then((hits) => this.videoClips(hits, title, artist, false)));
    }
    if (this.sources.invidiousUrls?.length) {
      attempts.push(invidiousVideos(this.fetchJson, this.sources.invidiousUrls, title, artist, this.sources.youtubeDispatcher)
        .then((hits) => this.videoClips(hits, title, artist, true)));
    }
    if (this.sources.youtubeWeb) {
      attempts.push(this.sources.youtubeWeb.search(this.fetchJson, title, artist)
        .then((hits) => this.videoClips(hits, title, artist, true)));
    }
    const settled = await Promise.allSettled(attempts);
    const clips = [...local, ...settled.flatMap((result) => result.status === "fulfilled" ? result.value : [])];
    let failed = settled.some((result) => result.status === "rejected");
    if (!clips.some((clip) => clip.playback === "direct") && this.pexelsKey) {
      try { clips.push(...await this.ambient()); } catch { failed = true; }
    }
    clips.push(...this.fallback);
    if (!clips.length && failed && settled.every((result) => result.status === "rejected")) {
      throw new Error("Clip sources unavailable");
    }
    return this.merge(title, artist, clips);
  }

  private async apple(title: string, artist: string): Promise<Clip[]> {
    const storefronts = await Promise.allSettled((this.sources.appleCountries ?? []).map(async (country) => {
      const url = new URL("https://itunes.apple.com/search");
      url.search = new URLSearchParams({ term: `${artist} ${title}`, media: "musicVideo", entity: "musicVideo", country, limit: "15" }).toString();
      const data = z.object({ results: z.array(z.object({
        trackId: z.number(), trackName: z.string(), artistName: z.string(),
        previewUrl: httpsUrl.optional(), trackViewUrl: httpsUrl
      })) }).parse(await this.json(url));
      return data.results
        .filter((item) => item.previewUrl && musicMatch(item.trackName, item.artistName, title, artist) >= 8.5)
        .sort((left, right) => musicMatch(right.trackName, right.artistName, title, artist) - musicMatch(left.trackName, left.artistName, title, artist));
    }));
    const matches = storefronts.flatMap((result) => result.status === "fulfilled" ? result.value : []);
    return [...new Map(matches.map((item) => [item.previewUrl!, item])).values()].slice(0, 6).map((item) => ({
      id: `apple-${item.trackId}`, title, artist, url: item.previewUrl!, playback: "direct" as const,
      kind: "preview" as const, source: "Apple Music · 30 сек", sourceUrl: item.trackViewUrl, offsetMs: 0
    }));
  }

  /** YouTube hits become external clips; the router upgrades them to embeds. */
  private videoClips(hits: VideoHit[], title: string, artist: string, searched: boolean): Clip[] {
    return hits
      .filter((hit) => !searched || musicMatch(hit.title, hit.channel, title, artist) >= 8.5)
      .sort((left, right) => searched
        ? musicMatch(right.title, right.channel, title, artist) - musicMatch(left.title, left.channel, title, artist) : 0)
      .slice(0, 3).map((hit) => ({
        id: `youtube-${hit.id}`, title, artist, playback: "external" as const, kind: "musicVideo" as const,
        source: `${hit.source}${hit.channel ? ` · ${hit.channel}` : ""}`.slice(0, 100),
        sourceUrl: `https://www.youtube.com/watch?v=${hit.id}`, offsetMs: 0
      }));
  }

  private async dailymotion(title: string, artist: string): Promise<Clip[]> {
    const url = new URL("https://api.dailymotion.com/videos");
    url.search = new URLSearchParams({ search: `${artist} ${title} official music video`, fields: "id,title,url,channel", limit: "8" }).toString();
    const data = z.object({ list: z.array(z.object({ id: z.string(), title: z.string(), url: httpsUrl, channel: z.string().optional() })) })
      .parse(await this.json(url));
    return data.list.filter((item) => item.channel === "music" && musicMatch(item.title, artist, title, artist) >= 8.5)
      .slice(0, 2).map((item) => ({
        id: `dailymotion-${item.id}`, title, artist, playback: "external" as const,
        kind: "musicVideo" as const, source: "Dailymotion", sourceUrl: item.url, offsetMs: 0
      }));
  }

  private async youtube(title: string, artist: string, apiKey: string): Promise<Clip[]> {
    const url = new URL("https://www.googleapis.com/youtube/v3/search");
    url.search = new URLSearchParams({ part: "snippet", q: `${artist} ${title} official music video`, type: "video",
      videoCategoryId: "10", videoEmbeddable: "true", videoSyndicated: "true", maxResults: "8", key: apiKey }).toString();
    const data = z.object({ items: z.array(z.object({
      id: z.object({ videoId: z.string() }), snippet: z.object({ title: z.string(), channelTitle: z.string() })
    })) }).parse(await this.json(url));
    return data.items.filter((item) => musicMatch(item.snippet.title, item.snippet.channelTitle, title, artist) >= 8.5)
      .slice(0, 3).map((item) => ({
        id: `youtube-${item.id.videoId}`, title, artist, playback: "external" as const,
        kind: "musicVideo" as const, source: `YouTube · ${item.snippet.channelTitle}`.slice(0, 100),
        sourceUrl: `https://www.youtube.com/watch?v=${encodeURIComponent(item.id.videoId)}`, offsetMs: 0
      }));
  }

  private async audioDb(title: string, artist: string, apiKey: string): Promise<Clip[]> {
    if (!/^[A-Za-z0-9_-]{1,100}$/.test(apiKey)) return [];
    const url = new URL(`https://www.theaudiodb.com/api/v1/json/${apiKey}/searchtrack.php`);
    url.search = new URLSearchParams({ s: artist, t: title }).toString();
    const data = z.object({ track: z.array(z.object({
      idTrack: z.string(), strTrack: z.string(), strArtist: z.string(), strMusicVid: z.string().nullable().optional()
    })).nullable().optional() }).parse(await this.json(url));
    return (data.track ?? []).flatMap((item): Clip[] => {
      if (!item.strMusicVid || musicMatch(item.strTrack, item.strArtist, title, artist) < 8.5) return [];
      const sourceUrl = safeVideoPage(item.strMusicVid);
      return sourceUrl ? [{ id: `audiodb-${item.idTrack}`, title, artist, playback: "external",
        kind: "musicVideo", source: "TheAudioDB", sourceUrl, offsetMs: 0 }] : [];
    }).slice(0, 2);
  }

  private async musicBrainz(title: string, artist: string): Promise<Clip[]> {
    const search = new URL("https://musicbrainz.org/ws/2/recording");
    search.search = new URLSearchParams({
      query: `recording:\"${lucene(title)}\" AND artist:\"${lucene(artist)}\"`, fmt: "json", limit: "5"
    }).toString();
    const result = z.object({ recordings: z.array(z.object({
      id: z.string().uuid(), title: z.string(), "artist-credit": z.array(z.object({ name: z.string() }))
    })) }).parse(await this.json(search));
    const match = result.recordings.find((item) =>
      musicMatch(item.title, item["artist-credit"].map((credit) => credit.name).join(", "), title, artist) >= 8.5);
    if (!match) return [];
    const lookup = new URL(`https://musicbrainz.org/ws/2/recording/${match.id}`);
    lookup.search = new URLSearchParams({ inc: "url-rels", fmt: "json" }).toString();
    const data = z.object({ relations: z.array(z.object({
      type: z.string(), url: z.object({ resource: z.string() })
    })).default([]) }).parse(await this.json(lookup));
    return data.relations.flatMap((relation, index): Clip[] => {
      if (!/video/i.test(relation.type)) return [];
      const sourceUrl = safeVideoPage(relation.url.resource);
      if (!sourceUrl) return [];
      return [{ id: `musicbrainz-${match.id}-${index}`, title, artist, playback: "external",
        kind: "musicVideo", source: `MusicBrainz · ${videoSourceName(sourceUrl)}`, sourceUrl, offsetMs: 0 }];
    }).slice(0, 3);
  }

  private async vimeo(title: string, artist: string, token: string): Promise<Clip[]> {
    const url = new URL("https://api.vimeo.com/videos");
    url.search = new URLSearchParams({ query: `${artist} ${title} official music video`, per_page: "8", sort: "relevant" }).toString();
    const data = z.object({ data: z.array(z.object({ uri: z.string(), name: z.string(), link: httpsUrl,
      user: z.object({ name: z.string() }) })) }).parse(await this.json(url, { Authorization: `Bearer ${token}` }));
    return data.data.filter((item) => musicMatch(item.name, item.user.name, title, artist) >= 8.5)
      .slice(0, 2).map((item) => ({
        id: `vimeo-${item.uri.split("/").at(-1)}`, title, artist, playback: "external" as const,
        kind: "musicVideo" as const, source: `Vimeo · ${item.user.name}`.slice(0, 100), sourceUrl: item.link, offsetMs: 0
      }));
  }

  private ambientPending?: Promise<Clip[]>;
  private ambientCache?: { expires: number; clips: Clip[] };
  private async ambient(): Promise<Clip[]> {
    if (this.ambientCache && this.ambientCache.expires > Date.now()) return this.ambientCache.clips;
    if (this.ambientPending) return this.ambientPending;
    this.ambientPending = (async () => {
      const url = new URL("https://api.pexels.com/v1/videos/search");
      url.search = new URLSearchParams({ query: "abstract lights", orientation: "landscape", per_page: "6" }).toString();
      const data = z.object({ videos: z.array(z.object({
        id: z.number(), url: httpsUrl, user: z.object({ name: z.string() }),
        video_files: z.array(z.object({ link: httpsUrl, file_type: z.string(), width: z.number().nullable() }))
      })) }).parse(await this.json(url, { Authorization: this.pexelsKey }));
      const clips = data.videos.flatMap((video): Clip[] => {
        const file = video.video_files.filter((file) => file.file_type === "video/mp4" && file.width && file.width <= 1920)
          .sort((a, b) => (b.width || 0) - (a.width || 0))[0];
        return file ? [{ id: `pexels-${video.id}`, title: "Свет и движение", artist: "", url: file.link,
          playback: "direct", kind: "ambient", source: `${video.user.name} · Pexels`, sourceUrl: video.url, offsetMs: 0 }] : [];
      });
      this.ambientCache = { expires: Date.now() + 3600000, clips };
      return clips;
    })().finally(() => { this.ambientPending = undefined; });
    return this.ambientPending;
  }
}

type ExtraClipFinder = (query: ClipQuery, request: Request) => Promise<Clip[]>;

export function createClipRouter(service: ClipService, extraFinder?: ExtraClipFinder, offsets?: ClipOffsetStore) {
  const router = Router();
  router.get("/embed/youtube", (request, response) => {
    const id = request.query.v;
    if (!isYoutubeId(id)) {
      response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid video id" } });
      return;
    }
    response.setHeader("Cache-Control", "public, max-age=86400");
    response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
    response.setHeader("Content-Security-Policy", [
      "default-src 'none'", "script-src 'unsafe-inline' https://www.youtube.com https://s.ytimg.com",
      "frame-src https://www.youtube.com https://www.youtube-nocookie.com", "style-src 'unsafe-inline'",
      "img-src https: data:", "connect-src https:"
    ].join("; "));
    response.type("html").send(youtubeEmbedPage(id));
  });
  router.post("/offset", (request, response) => {
    const body = offsetSchema.safeParse(request.body);
    if (!offsets || !body.success) {
      response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid offset" } });
      return;
    }
    const offsetMs = offsets.vote(clipTrackKey(body.data.title, body.data.artist), body.data.clipId,
      request.ip ?? "unknown", body.data.offsetMs);
    response.json({ clipId: body.data.clipId, offsetMs });
  });
  router.get("/", async (request, response) => {
    const query = querySchema.safeParse(request.query);
    if (!query.success) {
      response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid clip request" } });
      return;
    }
    try {
      const [base, extra] = await Promise.all([
        service.find(query.data.title, query.data.artist),
        extraFinder?.(query.data, request).catch(() => []) ?? Promise.resolve([])
      ]);
      response.setHeader("Cache-Control", query.data.yandexId ? "private, max-age=60" : "public, max-age=300");
      const embeds = new Set((query.data.embed ?? "").split(",").map((value) => value.trim()));
      const voted = offsets?.offsets(clipTrackKey(query.data.title, query.data.artist));
      const clips = service.merge(query.data.title, query.data.artist, base, extra)
        .map((clip) => withEmbed(clip, embeds.has("youtube")))
        .map((clip) => voted?.has(clip.id) ? { ...clip, offsetMs: voted.get(clip.id)! } : clip);
      response.json({ clips: clips.sort((left, right) => clipRank(left) - clipRank(right)) });
    } catch {
      response.setHeader("Cache-Control", "no-store");
      response.status(502).json({ error: { code: "CLIPS_UNAVAILABLE", message: "Источники видео временно недоступны" } });
    }
  });
  return router;
}

/** Upgrades YouTube links to the in-app embed for clients that support it. */
function withEmbed(clip: Clip, youtube: boolean): Clip {
  if (clip.playback === "embed") {
    return youtube ? clip : { ...clip, playback: "external", embed: undefined };
  }
  const id = youtube && clip.playback === "external" && clip.kind === "musicVideo" ? youtubeId(clip.sourceUrl) : undefined;
  return id ? { ...clip, playback: "embed", embed: { provider: "youtube", id } } : clip;
}

let sharedYoutubeProxy: Dispatcher | undefined;
/** CLIP_YOUTUBE_PROXY_URL, or the existing SoundCloud proxy as a fallback. */
function youtubeProxy(env: NodeJS.ProcessEnv) {
  const url = normalizeProxyUrl(env.CLIP_YOUTUBE_PROXY_URL || env.SOUNDCLOUD_PROXY_URL);
  if (!url) return undefined;
  sharedYoutubeProxy ??= new ProxyAgent(url);
  return sharedYoutubeProxy;
}

function youtubeWebFromEnvironment(env: NodeJS.ProcessEnv) {
  if (env.YOUTUBE_COOKIES_PATH) {
    try { return YoutubeWebSearch.fromFile(env.YOUTUBE_COOKIES_PATH); } catch (error) {
      console.error("YouTube cookies ignored", error instanceof Error ? error.message : error);
    }
  }
  return env.CLIP_YOUTUBE_WEB_SEARCH === "true" ? new YoutubeWebSearch() : undefined;
}

function clipRank(clip: Clip) {
  if (clip.playback === "direct" && clip.kind === "musicVideo") return 0;
  if (clip.playback === "embed" && clip.kind === "musicVideo") return 1;
  if (clip.playback === "direct" && clip.kind === "preview") return 2;
  if (clip.kind === "musicVideo") return 3;
  return 4;
}

function musicMatch(candidateTitle: string, candidateArtist: string, title: string, artist: string) {
  const wantedTitle = normalize(title);
  const wantedArtist = normalize(artist);
  const actualTitle = normalize(candidateTitle);
  const actualArtist = normalize(candidateArtist)
    .replace(/\b(?:vevo|official|music|channel)\b/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
  let score = 0;
  if (actualTitle === wantedTitle) score += 6;
  else if (actualTitle.includes(wantedTitle) || wantedTitle.includes(actualTitle)) score += 5;
  else score += overlap(actualTitle, wantedTitle) * 4;
  if (actualArtist === wantedArtist) score += 4;
  else score += overlap(actualArtist, wantedArtist) * 2;
  return score;
}

function overlap(left: string, right: string) {
  const leftTokens = new Set(left.split(" ").filter(Boolean));
  const rightTokens = new Set(right.split(" ").filter(Boolean));
  if (!leftTokens.size || !rightTokens.size) return 0;
  const common = [...leftTokens].filter((token) => rightTokens.has(token)).length;
  return common / Math.max(leftTokens.size, rightTokens.size);
}

function transliterate(value: string) {
  const letters: Record<string, string> = {
    а: "a", б: "b", в: "v", г: "g", д: "d", е: "e", ё: "e", ж: "zh", з: "z", и: "i", й: "i",
    к: "k", л: "l", м: "m", н: "n", о: "o", п: "p", р: "r", с: "s", т: "t", у: "u", ф: "f",
    х: "kh", ц: "ts", ч: "ch", ш: "sh", щ: "shch", ъ: "", ы: "y", ь: "", э: "e", ю: "yu", я: "ya"
  };
  return [...value].map((letter) => letters[letter] ?? letter).join("");
}

function safeVideoPage(value: string) {
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.username || url.password) return undefined;
    const host = url.hostname.toLowerCase();
    return ["youtube.com", "youtu.be", "vimeo.com", "dailymotion.com"].some(
      (allowed) => host === allowed || host.endsWith(`.${allowed}`)
    ) ? url.toString() : undefined;
  } catch { return undefined; }
}

function videoSourceName(value: string) {
  const host = new URL(value).hostname.replace(/^www\./, "");
  if (host === "youtu.be" || host.endsWith("youtube.com")) return "YouTube";
  if (host.endsWith("vimeo.com")) return "Vimeo";
  if (host.endsWith("dailymotion.com")) return "Dailymotion";
  return host;
}

function lucene(value: string) {
  return value.replace(/[+\-&|!(){}\[\]^"~*?:\\/]/g, "\\$&").slice(0, 200);
}
