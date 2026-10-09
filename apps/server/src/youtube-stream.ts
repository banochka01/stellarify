import { Readable } from "node:stream";
import type { Request, Response } from "express";
import { fetch as undiciFetch, type Dispatcher } from "undici";
import { isYoutubeId } from "./clip-embed.js";

/**
 * YouTube videos for Visual Stage, played as plain MP4 instead of the embed.
 *
 * The IFrame player increasingly answers "sign in to confirm you're not a
 * bot" on listener networks, and googlevideo links are bound to the IP that
 * resolved them. So the server resolves the stream through its YouTube proxy
 * and relays the bytes (with Range support); the client plays it like any
 * other direct clip, muted and synced to the audio.
 */
export type YoutubeFormat = {
  itag: number;
  url: string;
  mimeType: string;
  height?: number;
  bitrate?: number;
  contentLength?: string;
  audioQuality?: string;
};

type Resolved = { format: YoutubeFormat; expires: number };
type Fetcher = typeof undiciFetch;

const IOS_CLIENT = {
  clientName: "IOS",
  clientVersion: "20.10.4",
  deviceMake: "Apple",
  deviceModel: "iPhone16,2",
  osName: "iPhone",
  osVersion: "18.3.2.22D82",
  hl: "en",
  gl: "US"
} as const;
const IOS_USER_AGENT = "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)";

/** Picks a video the client can decode cheaply: H.264 MP4, up to 720p. */
export function pickYoutubeFormat(formats: YoutubeFormat[], maxHeight = 720): YoutubeFormat | undefined {
  const mp4 = formats.filter((format) => format.url && /^video\/mp4;.*avc1/.test(format.mimeType));
  const fitting = mp4.filter((format) => (format.height ?? 0) <= maxHeight);
  const ranked = (fitting.length ? fitting : mp4).sort((left, right) =>
    (right.height ?? 0) - (left.height ?? 0) || (left.bitrate ?? 0) - (right.bitrate ?? 0));
  return ranked[0];
}

export class YoutubeStreamService {
  private readonly cache = new Map<string, Resolved>();
  private readonly pending = new Map<string, Promise<YoutubeFormat | undefined>>();
  /** Only ids that clip search handed out may be relayed. */
  private readonly allowed = new Map<string, number>();

  constructor(
    private readonly dispatcher: Dispatcher | undefined,
    private readonly request: Fetcher = undiciFetch,
    private readonly now: () => number = Date.now
  ) {}

  get enabled() { return Boolean(this.dispatcher); }

  allow(id: string) {
    if (!isYoutubeId(id)) return;
    if (this.allowed.size >= 5000) this.allowed.delete(this.allowed.keys().next().value!);
    this.allowed.set(id, this.now() + 6 * 60 * 60_000);
  }

  isAllowed(id: string) {
    const expires = this.allowed.get(id);
    return expires !== undefined && expires > this.now();
  }

  async resolve(id: string): Promise<YoutubeFormat | undefined> {
    const cached = this.cache.get(id);
    if (cached && cached.expires > this.now()) return cached.format;
    const running = this.pending.get(id);
    if (running) return running;
    const task = this.fetchFormat(id).then((format) => {
      if (format) {
        if (this.cache.size >= 500) this.cache.delete(this.cache.keys().next().value!);
        // googlevideo ссылки живут около 6 часов; обновляем заранее.
        this.cache.set(id, { format, expires: this.now() + 60 * 60_000 });
      }
      return format;
    }).catch(() => undefined).finally(() => this.pending.delete(id));
    this.pending.set(id, task);
    return task;
  }

  forget(id: string) { this.cache.delete(id); }

  private async fetchFormat(id: string) {
    const response = await this.request("https://www.youtube.com/youtubei/v1/player?prettyPrint=false", {
      method: "POST",
      dispatcher: this.dispatcher,
      signal: AbortSignal.timeout(8000),
      headers: {
        "content-type": "application/json",
        "user-agent": IOS_USER_AGENT,
        "x-youtube-client-name": "5",
        "x-youtube-client-version": IOS_CLIENT.clientVersion
      },
      body: JSON.stringify({ videoId: id, context: { client: IOS_CLIENT }, contentCheckOk: true, racyCheckOk: true })
    });
    if (!response.ok) return undefined;
    const data = await response.json() as {
      playabilityStatus?: { status?: string };
      streamingData?: { formats?: YoutubeFormat[]; adaptiveFormats?: YoutubeFormat[] };
    };
    if (data.playabilityStatus?.status !== "OK") return undefined;
    const formats = [...(data.streamingData?.formats ?? []), ...(data.streamingData?.adaptiveFormats ?? [])];
    return pickYoutubeFormat(formats);
  }

  /** Relays the video with Range support; retries once with a fresh URL. */
  async relay(id: string, request: Request, response: Response) {
    if (!isYoutubeId(id) || !this.isAllowed(id) || !this.dispatcher) {
      response.status(404).json({ error: { code: "NOT_FOUND", message: "Video unavailable" } });
      return;
    }
    const range = typeof request.headers.range === "string" && /^bytes=\d*-\d*$/.test(request.headers.range)
      ? request.headers.range : undefined;
    for (let attempt = 0; attempt < 2; attempt++) {
      const format = await this.resolve(id);
      if (!format) break;
      const controller = new AbortController();
      request.on("close", () => controller.abort());
      let upstream;
      try {
        upstream = await this.request(format.url, {
          dispatcher: this.dispatcher,
          signal: controller.signal,
          headers: { "user-agent": IOS_USER_AGENT, ...(range ? { range } : { range: "bytes=0-" }) }
        });
      } catch {
        if (controller.signal.aborted) return;
        this.forget(id);
        continue;
      }
      if (upstream.status === 403 || upstream.status === 410 || !upstream.body) {
        await upstream.body?.cancel().catch(() => undefined);
        this.forget(id);
        continue;
      }
      response.status(upstream.status === 206 ? 206 : 200);
      response.setHeader("Content-Type", format.mimeType.split(";")[0] || "video/mp4");
      response.setHeader("Accept-Ranges", "bytes");
      response.setHeader("Cache-Control", "private, max-age=600");
      for (const header of ["content-length", "content-range"]) {
        const value = upstream.headers.get(header);
        if (value) response.setHeader(header, value);
      }
      const body = Readable.fromWeb(upstream.body as import("node:stream/web").ReadableStream);
      body.on("error", () => response.destroy());
      body.pipe(response);
      return;
    }
    if (!response.headersSent) {
      response.status(502).json({ error: { code: "VIDEO_UNAVAILABLE", message: "Видео временно недоступно" } });
    }
  }
}
