import "dotenv/config";
import { createServer } from "node:http";
import { createHash } from "node:crypto";
import { Readable } from "node:stream";
import cors from "cors";
import express from "express";
import { Server } from "socket.io";
import { z } from "zod";
import { createAccountRouter } from "./account-api.js";
import { AccountStore } from "./account-store.js";
import { parseImportPayload } from "./importer.js";
import { PlaylistImportService } from "./playlist-import.js";
import { ProviderGateway, ProviderGatewayError, type ProviderAccess } from "./provider-gateway.js";
import { providerCapabilities } from "./providers.js";
import { registerRoomHandlers } from "./rooms.js";
import { SoundCloudAdapter } from "./soundcloud.js";
import {
  isSoundCloudRelayTicket,
  SoundCloudAudioRelay
} from "./soundcloud-audio-relay.js";
import { YandexAdapter } from "./yandex.js";
import { YouTubeAdapter } from "./youtube.js";
import { WaveService, WaveSessionError } from "./wave.js";

const port = Number(process.env.PORT || 8787);
const webOrigin = process.env.WEB_ORIGIN || "http://localhost:5173";
const publicBaseUrl = parsePublicBaseUrl(process.env.PUBLIC_BASE_URL);
const app = express();
app.set("trust proxy", 1);
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: webOrigin,
    methods: ["GET", "POST"]
  }
});
const soundCloud = new SoundCloudAdapter({
  clientId: process.env.SOUNDCLOUD_CLIENT_ID,
  proxyUrl: process.env.SOUNDCLOUD_PROXY_URL
});
const soundCloudAudioRelay = new SoundCloudAudioRelay(
  process.env.SOUNDCLOUD_PROXY_URL
);
const yandex = new YandexAdapter(process.env.YANDEX_MUSIC_TOKEN);
const youtube = new YouTubeAdapter(process.env.YOUTUBE_API_KEY);
const gateway = new ProviderGateway([
  soundCloud,
  yandex,
  youtube
]);
const wave = new WaveService(gateway, yandex);
const playlistImports = new PlaylistImportService(yandex, youtube);
const accountStore = new AccountStore(
  process.env.AUTH_DB_PATH || "./data/resonance.sqlite",
  process.env.AUTH_PASSWORD_PEPPER || ""
);

app.disable("x-powered-by");
app.use(cors({ origin: webOrigin }));
app.use(express.json({ limit: "512kb" }));
app.use("/api/v1/account", createAccountRouter(accountStore));

app.get("/api/health", (_request, response) => {
  response.json({
    ok: true,
    service: "stellarify-server",
    now: new Date().toISOString()
  });
});

app.get("/api/client-version", (_request, response) => {
  response.json({
    version: process.env.CLIENT_VERSION || "0.3.2",
    notes: process.env.CLIENT_RELEASE_NOTES ||
      "Моя волна: Яндекс Rotor, SoundCloud и YouTube discovery, автопополнение и feedback.",
    downloads: {
      windows: "https://music.webcordes.ru/downloads/windows",
      android: "https://music.webcordes.ru/downloads/android",
      ios: "https://music.webcordes.ru/downloads/ios"
    }
  });
});

app.get("/api/providers", (_request, response) => {
  response.json({ providers: providerCapabilities });
});

const searchSchema = z.object({
  provider: z.enum(["soundcloud", "yandex", "youtube"]),
  q: z.string().trim().min(1).max(200),
  limit: z.coerce.number().int().min(1).max(50).default(20)
});

const resolveSchema = z.object({
  provider: z.enum(["soundcloud", "yandex"]),
  externalId: z.string().trim().min(1).max(200),
  quality: z.enum(["low", "medium", "high", "lossless"]).default("high")
});

const authValidationSchema = z.object({
  provider: z.enum(["soundcloud", "yandex", "youtube"])
});

app.get("/api/v1/playback/providers", (_request, response) => {
  response.json({ providers: gateway.listProviders() });
});

app.get("/api/v1/auth/validate", async (request, response) => {
  const input = authValidationSchema.safeParse(request.query);
  if (!input.success) {
    response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid validation request" } });
    return;
  }
  try {
    const access = providerAccess(request);
    await gateway.validate(input.data.provider, access);
    response.json({
      provider: input.data.provider,
      valid: true,
      proxyUsed: access?.useProxy === true
    });
  } catch (error) {
    sendGatewayError(response, error);
  }
});

app.get("/api/v1/catalog/search", async (request, response) => {
  const input = searchSchema.safeParse(request.query);
  if (!input.success) {
    response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid search request" } });
    return;
  }
  try {
    const access = providerAccess(request);
    const tracks = await gateway.search(
      input.data.provider,
      input.data.q,
      input.data.limit,
      access
    );
    response.json({ provider: input.data.provider, tracks });
  } catch (error) {
    sendGatewayError(response, error);
  }
});

app.post("/api/v1/playback/resolve", async (request, response) => {
  const input = resolveSchema.safeParse(request.body);
  if (!input.success) {
    response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid resolve request" } });
    return;
  }
  try {
    const access = providerAccess(request);
    let source = await gateway.resolve(
      input.data.provider,
      input.data.externalId,
      input.data.quality,
      access
    );
    if (input.data.provider === "soundcloud" && access?.useProxy) {
      const relay = soundCloudAudioRelay.issue(source);
      source = {
        ...source,
        streamUrl: absoluteRelayUrl(request, relay.streamUrl),
        expiresAt: relay.expiresAt
      };
    }
    response.json({ provider: input.data.provider, source });
  } catch (error) {
    sendGatewayError(response, error);
  }
});

const waveRequestSchema = z.object({
  seedQueries: z.array(z.string().trim().min(1).max(200)).max(20).default([]),
  enabledProviders: z.array(z.enum(["soundcloud", "yandex", "youtube"])).min(1).max(3).default(["soundcloud", "yandex", "youtube"]),
  discovery: z.number().min(0).max(1).default(.3),
  mood: z.enum(["fun", "active", "calm", "sad", "all"]).default("all"),
  language: z.enum(["not-russian", "russian", "any"]).default("any")
});
const waveFeedbackSchema = z.object({
  eventId: z.string().uuid(),
  type: z.enum(["started", "finished", "skipped", "liked", "disliked"]),
  trackId: z.string().trim().min(1).max(200),
  provider: z.enum(["soundcloud", "yandex", "youtube"]),
  batchId: z.string().trim().min(1).max(200).optional(),
  playedDurationMs: z.number().int().min(0).max(24 * 60 * 60 * 1000).default(0)
});

app.post("/api/v1/wave/sessions", async (request, response) => {
  const input = waveRequestSchema.safeParse(request.body);
  if (!input.success) return void response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid wave request" } });
  try {
    response.status(201).json(await wave.start(input.data, waveAccess(request)));
  } catch (error) { sendGatewayError(response, error); }
});

app.post("/api/v1/wave/sessions/:id/next", async (request, response) => {
  try {
    response.json(await wave.next(request.params.id, waveAccess(request)));
  } catch (error) { sendWaveError(response, error); }
});

app.post("/api/v1/wave/sessions/:id/feedback", async (request, response) => {
  const input = waveFeedbackSchema.safeParse(request.body);
  if (!input.success) return void response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid wave feedback" } });
  try {
    response.json(await wave.feedback(request.params.id, input.data, waveAccess(request)));
  } catch (error) { sendWaveError(response, error); }
});

app.delete("/api/v1/wave/sessions/:id", (request, response) => {
  response.status(wave.stop(request.params.id) ? 204 : 404).end();
});

app.all(
  "/api/v1/playback/soundcloud-relay/:ticket",
  async (request, response) => {
    const ticket = request.params.ticket;
    if (
      (request.method !== "GET" && request.method !== "HEAD") ||
      typeof ticket !== "string" ||
      !isSoundCloudRelayTicket(ticket)
    ) {
      response
        .status(request.method === "GET" || request.method === "HEAD" ? 404 : 405)
        .end();
      return;
    }
    try {
      const upstream = await soundCloudAudioRelay.open(
        ticket,
        request.method,
        {
          range: request.header("range"),
          "if-range": request.header("if-range"),
          "if-none-match": request.header("if-none-match"),
          "if-modified-since": request.header("if-modified-since")
        }
      );
      const safeStatus = [200, 206, 304, 416].includes(upstream.status)
        ? upstream.status
        : 502;
      if (safeStatus === 502) {
        response.status(502).json({
          error: {
            code: "UPSTREAM_ERROR",
            message: "SoundCloud audio relay received an invalid response"
          }
        });
        return;
      }
      response.status(safeStatus);
      for (const name of [
        "content-type",
        "content-length",
        "content-range",
        "accept-ranges",
        "etag",
        "last-modified"
      ]) {
        const value = upstream.headers.get(name);
        if (value) response.setHeader(name, value);
      }
      response.setHeader("cache-control", "private, no-store");
      if (request.method === "HEAD" || !upstream.body || safeStatus === 304) {
        response.end();
        return;
      }
      const body = Readable.from(
        upstream.body as unknown as AsyncIterable<Uint8Array>
      );
      response.on("close", () => body.destroy());
      body.on("error", () => response.destroy());
      body.pipe(response);
    } catch (error) {
      if (!response.headersSent) {
        sendGatewayError(response, error);
      } else {
        response.destroy();
      }
    }
  }
);

const importSchema = z.object({
  value: z.string().trim().min(1).max(20_000)
});

const playlistImportSchema = z.object({
  url: z.string().trim().url().max(4_096)
});

app.post("/api/v1/playlists/import", async (request, response) => {
  const result = playlistImportSchema.safeParse(request.body);
  if (!result.success) {
    response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Добавьте ссылку на плейлист" } });
    return;
  }
  try {
    const playlist = await playlistImports.importUrl(result.data.url, providerAccess(request));
    response.json({ playlist });
  } catch (error) {
    sendGatewayError(response, error);
  }
});

app.post("/api/import/preview", (request, response) => {
  const result = importSchema.safeParse(request.body);
  if (!result.success) {
    response.status(400).json({
      error: "Добавьте хотя бы одну ссылку или строку",
      details: result.error.flatten()
    });
    return;
  }

  const sources = parseImportPayload(result.data.value);
  response.json({
    sources,
    summary: sources.reduce<Record<string, number>>((accumulator, source) => {
      accumulator[source.provider] = (accumulator[source.provider] || 0) + 1;
      return accumulator;
    }, {})
  });
});

io.on("connection", (socket) => registerRoomHandlers(io, socket));

function sendGatewayError(response: express.Response, error: unknown) {
  if (error instanceof ProviderGatewayError) {
    response.status(error.status).json({
      error: { code: error.code, message: error.message }
    });
    return;
  }
  console.error("Unexpected provider gateway error", error);
  response.status(502).json({
    error: { code: "UPSTREAM_ERROR", message: "Provider request failed" }
  });
}

function sendWaveError(response: express.Response, error: unknown) {
  if (error instanceof WaveSessionError) {
    response.status(404).json({ error: { code: "WAVE_SESSION_NOT_FOUND", message: "Wave session expired or was not found" } });
    return;
  }
  sendGatewayError(response, error);
}

function providerAccess(request: express.Request) {
  const header = request.header("x-provider-token")?.trim();
  const useProxy = request.header("x-soundcloud-proxy")?.trim().toLowerCase() === "enabled";
  if (!header && !useProxy) return undefined;
  return {
    ...(header ? { token: header } : {}),
    useProxy,
    cacheScope: `${header ? createHash("sha256").update(header).digest("hex") : "server"}:${useProxy ? "proxy" : "direct"}`
  };
}

function waveAccess(request: express.Request) {
  const result: Partial<Record<"soundcloud" | "yandex" | "youtube", ProviderAccess>> = {};
  for (const provider of ["soundcloud", "yandex", "youtube"] as const) {
    const token = request.header(`x-${provider}-token`)?.trim();
    if (token && token.length <= 4096 && !/[\r\n]/.test(token)) {
      result[provider] = {
        token,
        cacheScope: createHash("sha256").update(token).digest("hex")
      };
    }
  }
  return result;
}

function absoluteRelayUrl(request: express.Request, path: string) {
  if (publicBaseUrl) return new URL(path, publicBaseUrl).toString();
  if (process.env.NODE_ENV === "production") {
    throw new Error("PUBLIC_BASE_URL is required for production audio relay");
  }
  const host = request.get("host");
  if (!host) throw new Error("Request host is missing");
  return new URL(path, `${request.protocol}://${host}`).toString();
}

function parsePublicBaseUrl(value?: string) {
  const raw = value?.trim();
  if (!raw) return undefined;
  const url = new URL(raw);
  if (url.protocol !== "https:" || !url.hostname || url.username || url.password) {
    throw new Error("PUBLIC_BASE_URL must be an absolute HTTPS URL without credentials");
  }
  return url;
}

httpServer.listen(port, () => {
  console.log(`Stellarify API listening on http://localhost:${port}`);
});
