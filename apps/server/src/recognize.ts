import express, { Router, type Request, type Response } from "express";
import { FixedWindowRateLimiter } from "./client-reports.js";

/**
 * Распознавание трека по короткому фрагменту с микрофона через AudD.
 * Включается только переменной AUDD_API_TOKEN. Аудио не сохраняется:
 * буфер живёт в памяти запроса и сразу уходит в AudD.
 */

type FetchLike = (input: string, init?: RequestInit) => Promise<globalThis.Response>;

export type RecognizedTrack = {
  title: string;
  artist: string;
  album?: string;
  releaseDate?: string;
  isrc?: string;
  durationMs?: number;
  spotifyId?: string;
  artworkUrl?: string;
};

export class RecognitionError extends Error {
  constructor(readonly code: "DISABLED" | "UPSTREAM" | "INVALID_AUDIO", message: string) {
    super(message);
  }
}

/** Фрагмент ~8 с: AAC/M4A ≈ 64–130 КБ, WAV 16 кГц моно ≈ 256 КБ. */
export const MIN_SAMPLE_BYTES = 4 * 1024;
export const MAX_SAMPLE_BYTES = 1536 * 1024;

const allowedTypes = new Set([
  "audio/mp4",
  "audio/m4a",
  "audio/x-m4a",
  "audio/aac",
  "audio/mpeg",
  "audio/wav",
  "audio/x-wav",
  "audio/wave",
  "audio/ogg",
  "audio/webm",
  "application/octet-stream"
]);

export function isAllowedSampleType(contentType: string | undefined) {
  const type = contentType?.split(";")[0]?.trim().toLowerCase();
  return Boolean(type && allowedTypes.has(type));
}

export class RecognitionService {
  constructor(
    private readonly apiToken: string | undefined,
    private readonly request: FetchLike = fetch,
    private readonly endpoint = "https://api.audd.io/",
    private readonly timeoutMs = 20_000
  ) {}

  static fromEnvironment(request: FetchLike = fetch, env: NodeJS.ProcessEnv = process.env) {
    const token = env.AUDD_API_TOKEN?.trim();
    return new RecognitionService(token || undefined, request);
  }

  get available() {
    return Boolean(this.apiToken);
  }

  async recognize(sample: Buffer, contentType = "application/octet-stream"): Promise<RecognizedTrack | null> {
    if (!this.apiToken) throw new RecognitionError("DISABLED", "Распознавание не настроено");
    if (sample.byteLength < MIN_SAMPLE_BYTES || sample.byteLength > MAX_SAMPLE_BYTES) {
      throw new RecognitionError("INVALID_AUDIO", "Фрагмент слишком короткий или слишком длинный");
    }
    const form = new FormData();
    form.set("api_token", this.apiToken);
    form.set("return", "spotify");
    form.set("file", new Blob([new Uint8Array(sample)], { type: contentType }), "sample");
    let payload: unknown;
    try {
      const response = await this.request(this.endpoint, {
        method: "POST",
        body: form,
        signal: AbortSignal.timeout(this.timeoutMs)
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      payload = await response.json();
    } catch {
      throw new RecognitionError("UPSTREAM", "Сервис распознавания не ответил");
    }
    return parseAuddResult(payload);
  }
}

function text(value: unknown, max = 300) {
  return typeof value === "string" && value.trim() ? value.trim().slice(0, max) : undefined;
}

/** Разбирает ответ AudD; `null` — трек не найден. */
export function parseAuddResult(payload: unknown): RecognizedTrack | null {
  if (!payload || typeof payload !== "object") {
    throw new RecognitionError("UPSTREAM", "Некорректный ответ сервиса распознавания");
  }
  const body = payload as Record<string, unknown>;
  if (body.status !== "success") {
    throw new RecognitionError("UPSTREAM", "Сервис распознавания вернул ошибку");
  }
  const result = body.result;
  if (!result || typeof result !== "object") return null;
  const data = result as Record<string, unknown>;
  const title = text(data.title);
  const artist = text(data.artist);
  if (!title || !artist) return null;
  const spotify = data.spotify && typeof data.spotify === "object"
    ? data.spotify as Record<string, unknown>
    : undefined;
  const spotifyId = text(spotify?.id, 64);
  const durationMs = typeof spotify?.duration_ms === "number" && Number.isFinite(spotify.duration_ms)
    ? Math.round(spotify.duration_ms)
    : undefined;
  const album = spotify?.album && typeof spotify.album === "object"
    ? spotify.album as Record<string, unknown>
    : undefined;
  const images = Array.isArray(album?.images) ? album.images : [];
  const artwork = images
    .map((image) => image && typeof image === "object" ? text((image as Record<string, unknown>).url, 500) : undefined)
    .find((url) => url?.startsWith("https://"));
  const isrc = spotify?.external_ids && typeof spotify.external_ids === "object"
    ? text((spotify.external_ids as Record<string, unknown>).isrc, 32)
    : undefined;
  return {
    title,
    artist,
    ...(text(data.album) ? { album: text(data.album)! } : {}),
    ...(text(data.release_date, 32) ? { releaseDate: text(data.release_date, 32)! } : {}),
    ...(isrc ? { isrc } : {}),
    ...(durationMs ? { durationMs } : {}),
    ...(spotifyId && /^[A-Za-z0-9]{10,40}$/u.test(spotifyId) ? { spotifyId } : {}),
    ...(artwork ? { artworkUrl: artwork } : {})
  };
}

export function createRecognizeRouter(
  service: RecognitionService,
  authenticate: (accessToken: string) => { id: string },
  limiter = new FixedWindowRateLimiter(20, 10 * 60_000)
) {
  const router = Router();

  router.get("/status", (_request, response) => {
    response.setHeader("cache-control", "no-store");
    response.json({ available: service.available, sampleSeconds: 8 });
  });

  const requireAccount = (request: Request, response: Response) => {
    const match = request.header("authorization")?.match(/^Bearer ([A-Za-z0-9_-]{30,256})$/u);
    if (!match?.[1]) {
      response.status(401).json({ error: { code: "AUTH_REQUIRED", message: "Войдите в аккаунт" } });
      return undefined;
    }
    try {
      return authenticate(match[1]);
    } catch {
      response.status(401).json({ error: { code: "INVALID_SESSION", message: "Сессия истекла" } });
      return undefined;
    }
  };

  router.post(
    "/",
    (request, response, next) => {
      if (!service.available) {
        response.status(503).json({ error: { code: "RECOGNITION_DISABLED", message: "Распознавание не настроено" } });
        return;
      }
      const user = requireAccount(request, response);
      if (!user) return;
      if (!limiter.allow(user.id)) {
        response.status(429).json({ error: { code: "RATE_LIMITED", message: "Слишком много попыток, попробуйте позже" } });
        return;
      }
      if (!isAllowedSampleType(request.header("content-type"))) {
        response.status(415).json({ error: { code: "UNSUPPORTED_AUDIO", message: "Неподдерживаемый формат фрагмента" } });
        return;
      }
      next();
    },
    express.raw({ type: () => true, limit: MAX_SAMPLE_BYTES }),
    async (request, response) => {
      const sample = Buffer.isBuffer(request.body) ? request.body : Buffer.alloc(0);
      try {
        const track = await service.recognize(sample, request.header("content-type")?.split(";")[0]?.trim());
        response.setHeader("cache-control", "no-store");
        response.json({ track });
      } catch (error) {
        if (error instanceof RecognitionError) {
          const status = error.code === "INVALID_AUDIO" ? 400 : error.code === "DISABLED" ? 503 : 502;
          response.status(status).json({ error: { code: `RECOGNITION_${error.code}`, message: error.message } });
          return;
        }
        response.status(500).json({ error: { code: "INTERNAL", message: "Не удалось распознать трек" } });
      }
    }
  );

  return router;
}
