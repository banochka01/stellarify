import { readFileSync } from "node:fs";
import { Router, type Request } from "express";
import { z } from "zod";

const httpsUrl = z.string().url().max(2048).refine((value) => {
  const url = new URL(value);
  return url.protocol === "https:" && !url.username && !url.password;
});
export const clipSchema = z.object({
  id: z.string().min(1).max(200),
  title: z.string().min(1).max(200),
  artist: z.string().max(200).default(""),
  url: httpsUrl.optional(),
  playback: z.enum(["direct", "external"]).default("direct"),
  kind: z.enum(["musicVideo", "preview", "ambient"]),
  source: z.string().min(1).max(100),
  sourceUrl: httpsUrl,
  offsetMs: z.number().int().min(-600000).max(600000).default(0)
}).superRefine((clip, context) => {
  if (clip.playback === "direct" && !clip.url) {
    context.addIssue({ code: "custom", path: ["url"], message: "Direct clips require a media URL" });
  }
});
export type Clip = z.infer<typeof clipSchema>;
export type ClipQuery = { title: string; artist: string; yandexId?: string };
export type ClipSourceOptions = {
  appleCountries?: string[];
  dailymotion?: boolean;
  youtubeKey?: string;
  vimeoToken?: string;
};

// Public-domain ISS timelapse, credited on NASA's original asset page.
export const builtInClips: Clip[] = ["webm", "mp4"].map((format) => ({
  id: `nasa-aurora-${format}`, title: "Полярное сияние с МКС", artist: "",
  url: `https://svs.gsfc.nasa.gov/vis/a030000/a031200/a031281/ISS067_20220817_aurora_1080p25.${format}`,
  playback: "direct", kind: "ambient",
  source: "NASA Johnson Space Center · Earth Science and Remote Sensing Unit",
  sourceUrl: "https://svs.gsfc.nasa.gov/31281/", offsetMs: 0
}));
const catalogSchema = z.object({ clips: z.array(clipSchema).max(2000) });
const querySchema = z.object({
  title: z.string().trim().min(1).max(200),
  artist: z.string().trim().min(1).max(200),
  yandexId: z.string().trim().regex(/^\d+(?::\d+)?$/).optional()
});
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
      .filter((country) => /^[a-z]{2}$/.test(country)).slice(0, 4);
    return new ClipService(catalog,
      (env.CLIP_PROVIDER_URLS || "").split(",").map((url) => url.trim()).filter(Boolean).slice(0, 12),
      env.PEXELS_API_KEY || "", request,
      env.CLIP_BUILTIN_ENABLED === "false" ? [] : builtInClips,
      {
        appleCountries: env.CLIP_APPLE_ENABLED === "false" ? [] : appleCountries,
        dailymotion: env.CLIP_DAILYMOTION_ENABLED !== "false",
        youtubeKey: env.YOUTUBE_API_KEY || "",
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

  private async json(url: URL, headers?: Record<string, string>) {
    const response = await this.request(url, {
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
    if (this.sources.youtubeKey) attempts.push(this.youtube(title, artist, this.sources.youtubeKey));
    if (this.sources.vimeoToken) attempts.push(this.vimeo(title, artist, this.sources.vimeoToken));
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
    for (const country of this.sources.appleCountries ?? []) {
      const url = new URL("https://itunes.apple.com/search");
      url.search = new URLSearchParams({ term: `${artist} ${title}`, media: "musicVideo", entity: "musicVideo", country, limit: "15" }).toString();
      const data = z.object({ results: z.array(z.object({
        trackId: z.number(), trackName: z.string(), artistName: z.string(),
        previewUrl: httpsUrl.optional(), trackViewUrl: httpsUrl
      })) }).parse(await this.json(url));
      const matches = data.results
        .filter((item) => item.previewUrl && musicMatch(item.trackName, item.artistName, title, artist) >= 8.5)
        .sort((left, right) => musicMatch(right.trackName, right.artistName, title, artist) - musicMatch(left.trackName, left.artistName, title, artist));
      if (matches.length) return matches.slice(0, 2).map((item) => ({
        id: `apple-${item.trackId}`, title, artist, url: item.previewUrl!, playback: "direct" as const,
        kind: "preview" as const, source: "Apple Music · 30 сек", sourceUrl: item.trackViewUrl, offsetMs: 0
      }));
    }
    return [];
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

export function createClipRouter(service: ClipService, extraFinder?: ExtraClipFinder) {
  const router = Router();
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
      response.json({ clips: service.merge(query.data.title, query.data.artist, base, extra) });
    } catch {
      response.setHeader("Cache-Control", "no-store");
      response.status(502).json({ error: { code: "CLIPS_UNAVAILABLE", message: "Источники видео временно недоступны" } });
    }
  });
  return router;
}

function clipRank(clip: Clip) {
  if (clip.playback === "direct" && clip.kind === "musicVideo") return 0;
  if (clip.playback === "direct" && clip.kind === "preview") return 1;
  if (clip.kind === "musicVideo") return 2;
  return 3;
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
