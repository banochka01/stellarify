import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import type { Dispatcher } from "undici";
import { z } from "zod";
import { youtubeId } from "./clip-embed.js";

/** Fetches JSON with the clip service's size and timeout limits. */
export type JsonFetcher = (url: URL, init?: {
  method?: "GET" | "POST"; headers?: Record<string, string>; body?: string; dispatcher?: Dispatcher;
}) => Promise<unknown>;

/** A YouTube video found for a track, before it becomes a Clip. */
export type VideoHit = { id: string; title: string; channel: string; source: string };

/**
 * song.link maps a track page from a known service to the same track on
 * YouTube. Its public API now requires a key (CLIP_SONGLINK_KEY); the iTunes
 * catalog supplies the starting URL when the track has no Yandex id.
 */
export async function songLinkVideos(json: JsonFetcher, key: string, title: string, artist: string, yandexId?: string, country = "ru"): Promise<VideoHit[]> {
  let start = yandexId ? `https://music.yandex.ru/track/${yandexId.split(":")[0]}` : undefined;
  if (!start) {
    const search = new URL("https://itunes.apple.com/search");
    search.search = new URLSearchParams({ term: `${artist} ${title}`, media: "music", entity: "song", country, limit: "5" }).toString();
    const songs = z.object({ results: z.array(z.object({
      trackName: z.string(), artistName: z.string(), trackViewUrl: z.string().url()
    })) }).parse(await json(search));
    start = songs.results[0]?.trackViewUrl;
  }
  if (!start) return [];
  const url = new URL("https://api.song.link/v1-alpha.1/links");
  url.search = new URLSearchParams({ url: start, userCountry: country.toUpperCase(), key }).toString();
  const data = z.object({
    linksByPlatform: z.record(z.string(), z.object({ url: z.string(), entityUniqueId: z.string().optional() })).default({}),
    entitiesByUniqueId: z.record(z.string(), z.object({ title: z.string().optional(), artistName: z.string().optional() })).default({})
  }).parse(await json(url));
  const hits: VideoHit[] = [];
  for (const platform of ["youtube", "youtubeMusic"]) {
    const link = data.linksByPlatform[platform];
    const id = link ? youtubeId(link.url) : undefined;
    if (!id || hits.some((hit) => hit.id === id)) continue;
    const entity = link?.entityUniqueId ? data.entitiesByUniqueId[link.entityUniqueId] : undefined;
    hits.push({ id, title: entity?.title ?? title, channel: entity?.artistName ?? artist, source: "YouTube · song.link" });
  }
  return hits;
}

/** Search through Invidious instances; only video ids leave this function. */
export async function invidiousVideos(json: JsonFetcher, instances: string[], title: string, artist: string, dispatcher?: Dispatcher): Promise<VideoHit[]> {
  const item = z.object({ type: z.string(), videoId: z.string().optional(), title: z.string().optional(), author: z.string().optional() });
  for (const instance of instances) {
    try {
      const url = new URL("/api/v1/search", instance);
      url.search = new URLSearchParams({ q: `${artist} ${title} official music video`, type: "video", sort_by: "relevance" }).toString();
      const results = z.array(item).parse(await json(url, { dispatcher }));
      return results.flatMap((result) => result.type === "video" && result.videoId && /^[A-Za-z0-9_-]{11}$/.test(result.videoId)
        ? [{ id: result.videoId, title: result.title ?? "", channel: result.author ?? "", source: "YouTube · поиск" }] : []).slice(0, 8);
    } catch { /* следующее зеркало */ }
  }
  return [];
}

/**
 * YouTube's own web search, optionally signed in with a server-side cookie
 * file (Netscape format, as exported by browser extensions). The cookies never
 * leave the server and are only sent to www.youtube.com. YouTube is not
 * reachable from the production host directly, so requests can go through a
 * proxy dispatcher.
 */
export class YoutubeWebSearch {
  constructor(
    private readonly cookies: Map<string, string> = new Map(),
    private readonly dispatcher?: Dispatcher
  ) {}

  withDispatcher(dispatcher?: Dispatcher) { return new YoutubeWebSearch(this.cookies, dispatcher); }

  static fromFile(path: string) {
    const cookies = new Map<string, string>();
    for (const line of readFileSync(path, "utf8").split(/\r?\n/)) {
      const fields = line.replace(/^#HttpOnly_/, "").split("\t");
      if (line.startsWith("#") && !line.startsWith("#HttpOnly_")) continue;
      if (fields.length < 7 || !/(^|\.)youtube\.com$/.test(fields[0]!)) continue;
      cookies.set(fields[5]!, fields[6]!.trim());
    }
    if (!cookies.size) throw new Error("No youtube.com cookies in file");
    return new YoutubeWebSearch(cookies);
  }

  get signedIn() { return this.cookies.has("SAPISID") || this.cookies.has("__Secure-3PAPISID"); }

  headers(now = Date.now()): Record<string, string> {
    const origin = "https://www.youtube.com";
    const headers: Record<string, string> = { origin, referer: `${origin}/`, "x-origin": origin };
    if (!this.cookies.size) return headers;
    headers.cookie = [...this.cookies].map(([name, value]) => `${name}=${value}`).join("; ");
    const sapisid = this.cookies.get("SAPISID") ?? this.cookies.get("__Secure-3PAPISID");
    if (sapisid) {
      const timestamp = Math.floor(now / 1000);
      const hash = createHash("sha1").update(`${timestamp} ${sapisid} ${origin}`).digest("hex");
      headers.authorization = `SAPISIDHASH ${timestamp}_${hash}`;
      headers["x-goog-authuser"] = "0";
    }
    return headers;
  }

  async search(json: JsonFetcher, title: string, artist: string): Promise<VideoHit[]> {
    const data = await json(new URL("https://www.youtube.com/youtubei/v1/search?prettyPrint=false"), {
      method: "POST",
      dispatcher: this.dispatcher,
      headers: { ...this.headers(), "content-type": "application/json" },
      body: JSON.stringify({
        context: { client: { clientName: "WEB", clientVersion: "2.20260901.00.00", hl: "ru", gl: "RU" } },
        query: `${artist} ${title} official music video`,
        params: "EgIQAQ%3D%3D"
      })
    });
    const hits: VideoHit[] = [];
    const visit = (node: unknown, depth: number) => {
      if (hits.length >= 8 || depth > 40 || !node || typeof node !== "object") return;
      if (Array.isArray(node)) { node.forEach((child) => visit(child, depth + 1)); return; }
      const record = node as Record<string, unknown>;
      const video = record.videoRenderer as Record<string, unknown> | undefined;
      if (video && typeof video.videoId === "string" && /^[A-Za-z0-9_-]{11}$/.test(video.videoId)) {
        hits.push({ id: video.videoId, title: runs(video.title), channel: runs(video.ownerText ?? video.longBylineText), source: "YouTube" });
        return;
      }
      Object.values(record).forEach((child) => visit(child, depth + 1));
    };
    visit(data, 0);
    return hits;
  }
}

function runs(value: unknown): string {
  const text = value as { runs?: Array<{ text?: string }>; simpleText?: string } | undefined;
  return text?.simpleText ?? text?.runs?.map((run) => run.text ?? "").join("") ?? "";
}
