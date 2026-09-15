import { readFileSync } from "node:fs";
import { Router } from "express";
import { z } from "zod";

const httpsUrl = z.string().url().max(2048).refine((value) => {
  const url = new URL(value);
  return url.protocol === "https:" && !url.username && !url.password;
});
export const clipSchema = z.object({
  id: z.string().min(1).max(200),
  title: z.string().min(1).max(200),
  artist: z.string().max(200).default(""),
  url: httpsUrl,
  kind: z.enum(["musicVideo", "ambient"]),
  source: z.string().min(1).max(100),
  sourceUrl: httpsUrl,
  offsetMs: z.number().int().min(-600000).max(600000).default(0)
});
export type Clip = z.infer<typeof clipSchema>;
// Public-domain ISS timelapse, credited on NASA's original asset page.
// WebM is the lightweight default; MP4 is a decoder compatibility fallback.
export const builtInClips: Clip[] = ["webm", "mp4"].map((format) => ({
  id: `nasa-aurora-${format}`, title: "Полярное сияние с МКС", artist: "",
  url: `https://svs.gsfc.nasa.gov/vis/a030000/a031200/a031281/ISS067_20220817_aurora_1080p25.${format}`,
  kind: "ambient", source: "NASA Johnson Space Center · Earth Science and Remote Sensing Unit",
  sourceUrl: "https://svs.gsfc.nasa.gov/31281/", offsetMs: 0
}));
const catalogSchema = z.object({ clips: z.array(clipSchema).max(2000) });
const querySchema = z.object({
  title: z.string().trim().min(1).max(200),
  artist: z.string().trim().min(1).max(200)
});
const normalize = (value: string) => value.normalize("NFKC").toLocaleLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();

export class ClipService {
  private readonly cache = new Map<string, { expires: number; clips: Clip[] }>();
  private readonly pending = new Map<string, Promise<Clip[]>>();
  constructor(
    private readonly catalog: Clip[] = [],
    private readonly endpoints: string[] = [],
    private readonly pexelsKey = "",
    private readonly request: typeof fetch = fetch,
    private readonly fallback: Clip[] = []
  ) {
    endpoints.forEach((url) => httpsUrl.parse(url));
  }

  static fromEnvironment() {
    const catalog = process.env.CLIP_CATALOG_PATH
      ? catalogSchema.parse(JSON.parse(readFileSync(process.env.CLIP_CATALOG_PATH, "utf8"))).clips : [];
    return new ClipService(catalog,
      (process.env.CLIP_PROVIDER_URLS || "").split(",").map((url) => url.trim()).filter(Boolean).slice(0, 4),
      process.env.PEXELS_API_KEY || "", fetch,
      process.env.CLIP_BUILTIN_ENABLED === "false" ? [] : builtInClips);
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
      this.cache.set(key, { expires: Date.now() + 300000, clips });
      return clips;
    }).finally(() => this.pending.delete(key));
    this.pending.set(key, task);
    return task;
  }

  private async json(url: URL, headers?: Record<string, string>) {
    const response = await this.request(url, { headers, redirect: "error", signal: AbortSignal.timeout(6000) });
    if (!response.ok) throw new Error("Clip source unavailable");
    // Bound streamed bodies too: Content-Length may be missing or inaccurate.
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
    const matches = (clip: Clip) => clip.kind === "ambient" ||
      (normalize(clip.title) === normalize(title) && normalize(clip.artist) === normalize(artist));
    const local = this.catalog.filter(matches);
    const attempts = await Promise.allSettled(this.endpoints.map(async (endpoint) => {
      const url = new URL(endpoint);
      url.searchParams.set("title", title);
      url.searchParams.set("artist", artist);
      return catalogSchema.parse(await this.json(url)).clips.filter(matches);
    }));
    const clips = [...local, ...attempts.flatMap((result) => result.status === "fulfilled" ? result.value : [])];
    let failed = attempts.some((result) => result.status === "rejected");
    if (!clips.length && this.pexelsKey) {
      try { clips.push(...await this.ambient()); } catch { failed = true; }
    }
    clips.push(...this.fallback);
    if (!clips.length && failed) {
      throw new Error("Clip sources unavailable");
    }
    return [...new Map(clips.sort((a, b) => Number(a.kind === "ambient") - Number(b.kind === "ambient"))
      .map((clip) => [clip.url, clip])).values()].slice(0, 8);
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
          kind: "ambient", source: `${video.user.name} · Pexels`, sourceUrl: video.url, offsetMs: 0 }] : [];
      });
      this.ambientCache = { expires: Date.now() + 3600000, clips };
      return clips;
    })().finally(() => { this.ambientPending = undefined; });
    return this.ambientPending;
  }
}

export function createClipRouter(service: ClipService) {
  const router = Router();
  router.get("/", async (request, response) => {
    const query = querySchema.safeParse(request.query);
    if (!query.success) {
      response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid clip request" } });
      return;
    }
    try {
      response.setHeader("Cache-Control", "public, max-age=60");
      response.json({ clips: await service.find(query.data.title, query.data.artist) });
    } catch {
      response.setHeader("Cache-Control", "no-store");
      response.status(502).json({ error: { code: "CLIPS_UNAVAILABLE", message: "Источники видео временно недоступны" } });
    }
  });
  return router;
}
