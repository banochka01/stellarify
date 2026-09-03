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
import { AccountError } from "./account-store.js";
import { AccessControl, accessError, createSubscriptionRouter } from "./subscription-api.js";
import { SubscriptionStore, SubscriptionError, hashSecret } from "./subscriptions.js";
import { parseImportPayload } from "./importer.js";
import { PlaylistImportService } from "./playlist-import.js";
import { LyricsError, LyricsService } from "./lyrics.js";
import { ProviderGateway, ProviderGatewayError, type ProviderAccess } from "./provider-gateway.js";
import { providerCapabilities } from "./providers.js";
import { registerRoomHandlers, roomWaveUserIds } from "./rooms.js";
import { SoundCloudAdapter } from "./soundcloud.js";
import {
  isSoundCloudRelayTicket,
  SoundCloudAudioRelay
} from "./soundcloud-audio-relay.js";
import { YandexAdapter } from "./yandex.js";
import { YouTubeAdapter } from "./youtube.js";
import { WaveService, WaveSessionError } from "./wave.js";
import { WavePersonalizer } from "./wave-personalizer.js";

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
const playlistImports = new PlaylistImportService(yandex, youtube);
const lyrics = new LyricsService();
const accountStore = new AccountStore(
  process.env.AUTH_DB_PATH || "./data/resonance.sqlite",
  process.env.AUTH_PASSWORD_PEPPER || ""
);
const wavePersonalizer = new WavePersonalizer(accountStore, {
  apiKey: process.env.AGENTROUTER_API_KEY,
  baseUrl: process.env.AGENTROUTER_BASE_URL,
  model: process.env.AGENTROUTER_MODEL,
  timeoutMs: optionalNumber(process.env.AGENTROUTER_TIMEOUT_MS),
  cacheMs: optionalNumber(process.env.AGENTROUTER_CACHE_MS)
});
const wave = new WaveService(gateway, yandex, wavePersonalizer);
const subscriptionStore = new SubscriptionStore(process.env.AUTH_DB_PATH || "./data/resonance.sqlite");
const accessControl = new AccessControl(accountStore, subscriptionStore);

app.disable("x-powered-by");
app.use(cors({ origin: webOrigin }));
app.use(express.json({ limit: "512kb" }));
app.use("/api/v1/subscription", createSubscriptionRouter(accessControl));
app.use("/api/v1/account/library", accessControl.middleware("library.cloudSync"));
app.use("/api/v1/account", createAccountRouter(accountStore));

// Enforce before any provider traffic, including legacy clients and alternate import paths.
app.use(["/api/v1/catalog/search", "/api/v1/playback/resolve", "/api/v1/auth/validate"], (request, response, next) => {
  const provider = request.method === "GET" ? request.query.provider : request.body?.provider;
  try {
    if (provider !== "soundcloud" && provider !== "yandex") throw new SubscriptionError("NATIVE_SOURCE_REQUIRED", "Источник не поддерживает собственный плеер Resonance", 400);
    accessControl.require(request, provider === "soundcloud" ? "playback.soundcloud" : "playback.yandex");
    next();
  } catch (error) { accessError(response, error); }
});
app.use(["/api/v1/playlists/import", "/api/import/preview"], accessControl.middleware("library.import"));
app.use("/api/v1/wave", accessControl.middleware("wave.standard"));

app.get("/api/health", (_request, response) => {
  response.json({
    ok: true,
    service: "stellarify-server",
    wavePersonalization: wavePersonalizer.enabled ? "agentrouter" : "deterministic",
    ...(wavePersonalizer.enabled ? { waveModel: wavePersonalizer.model } : {}),
    now: new Date().toISOString()
  });
});

app.get("/api/client-version", (_request, response) => {
  response.json({
    version: process.env.CLIENT_VERSION || "1.2.0",
    notes: process.env.CLIENT_RELEASE_NOTES ||
      "Resonance 1.2 Visual Stage: полноэкранные клипы, кинематографичный Lyrics и локальный OBS-виджет «Сейчас играет».",
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

const lyricsQuerySchema = z.object({
  title: z.string().trim().min(1).max(200),
  artist: z.string().trim().min(1).max(200),
  album: z.string().trim().min(1).max(200).optional(),
  durationMs: z.coerce.number().int().min(1).max(24 * 60 * 60 * 1_000).optional()
});

app.get("/api/v1/lyrics", async (request, response) => {
  const input = lyricsQuerySchema.safeParse(request.query);
  if (!input.success) {
    response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid lyrics request" } });
    return;
  }
  try {
    const result = await lyrics.find(input.data);
    if (!result) {
      response.status(404).json({ error: { code: "LYRICS_NOT_FOUND", message: "Текст для этого трека пока не найден" } });
      return;
    }
    response.setHeader("cache-control", "public, max-age=900, stale-while-revalidate=3600");
    response.json(result);
  } catch (error) {
    if (error instanceof LyricsError) {
      response.status(error.status).json({ error: { code: error.code, message: "Не удалось загрузить текст песни" } });
      return;
    }
    response.status(500).json({ error: { code: "INTERNAL_ERROR", message: "Не удалось загрузить текст песни" } });
  }
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
    const identity = accessControl.fromRequest(request);
    const entitlement = subscriptionStore.require(input.data.provider === "soundcloud" ? "playback.soundcloud" : "playback.yandex", identity.userId, identity.guestToken);
    const expiry = Math.min(Date.parse(entitlement.expiresAt!), source.expiresAt ? Date.parse(source.expiresAt) : Infinity);
    source = { ...source, expiresAt: new Date(expiry).toISOString() };
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
  prompt: z.string().trim().max(500).optional(),
  seedQueries: z.array(z.string().trim().min(1).max(200)).max(20).default([]),
  excludedTerms: z.array(z.string().trim().min(1).max(80)).max(10).default([]),
  enabledProviders: z.array(z.enum(["soundcloud", "yandex"])).min(1).max(2).default(["soundcloud", "yandex"]),
  discovery: z.number().min(0).max(1).default(.3),
  mood: z.enum(["fun", "active", "calm", "sad", "all"]).default("all"),
  language: z.enum(["not-russian", "russian", "any"]).default("any"),
  roomCode: z.string().trim().regex(/^[A-F0-9]{6}$/).optional()
});
const waveFeedbackSchema = z.object({
  eventId: z.string().uuid(),
  type: z.enum(["started", "finished", "skipped", "liked", "disliked"]),
  trackId: z.string().trim().min(1).max(200),
  provider: z.enum(["soundcloud", "yandex"]),
  batchId: z.string().trim().min(1).max(200).optional(),
  playedDurationMs: z.number().int().min(0).max(24 * 60 * 60 * 1000).default(0)
});
const waveCheckpointSchema = z.object({
  trackId: z.string().trim().min(1).max(200),
  provider: z.enum(["soundcloud", "yandex"]),
  positionMs: z.number().int().min(0).max(24 * 60 * 60 * 1000)
}).strict();

app.post("/api/v1/wave/sessions", async (request, response) => {
  const input = waveRequestSchema.safeParse(request.body);
  if (!input.success) return void response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid wave request" } });
  try {
    const identity = accessControl.fromRequest(request);
    const entitlement = subscriptionStore.snapshot(identity.userId, identity.guestToken);
    subscriptionStore.consumeGuestWave(identity.userId, identity.guestToken);
    const personalized = entitlement.capabilities["wave.personalized"];
    const roomUsers = personalized && input.data.roomCode && identity.userId
      ? roomWaveUserIds(input.data.roomCode, identity.userId)
      : [];
    response.status(201).json(await wave.start({
      ...input.data,
      enabledProviders: input.data.enabledProviders.filter(p => entitlement.providers.includes(p)),
      seedQueries: personalized ? input.data.seedQueries : [],
      prompt: personalized ? input.data.prompt : undefined,
      excludedTerms: personalized ? input.data.excludedTerms : [],
      discovery: personalized ? input.data.discovery : .3,
    }, waveAccess(request), waveOwner(request), personalized ? identity.userId : undefined,
    roomUsers.length ? roomUsers : identity.userId ? [identity.userId] : []));
  } catch (error) { sendGatewayError(response, error); }
});

app.get("/api/v1/wave/active", (request, response) => {
  try {
    const active = wave.active(waveOwner(request));
    if (!active) return void response.status(204).end();
    response.json(active);
  } catch (error) { sendWaveError(response, error); }
});

app.get("/api/v1/wave/profile", (request, response) => {
  try {
    const identity = accessControl.fromRequest(request);
    if (!identity.userId) throw new SubscriptionError("AUTH_REQUIRED", "Войдите в аккаунт", 401);
    const signals = accountStore.getWaveTasteSignals(identity.userId);
    const artists = new Map<string, number>();
    for (const item of [...signals.favorites, ...signals.playlistTracks, ...signals.listening]) {
      artists.set(item.artist, (artists.get(item.artist) ?? 0) + 1);
    }
    response.json({
      feedbackCount: signals.listening.length,
      favoritesCount: signals.favorites.length,
      playlistTracksCount: signals.playlistTracks.length,
      topArtists: [...artists.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5).map(([artist]) => artist)
    });
  } catch (error) { sendWaveError(response, error); }
});

app.delete("/api/v1/wave/profile", (request, response) => {
  try {
    const identity = accessControl.fromRequest(request);
    if (!identity.userId) throw new SubscriptionError("AUTH_REQUIRED", "Войдите в аккаунт", 401);
    accountStore.clearWaveFeedback(identity.userId);
    wavePersonalizer.invalidate(identity.userId);
    response.status(204).end();
  } catch (error) { sendWaveError(response, error); }
});

app.post("/api/v1/wave/sessions/:id/next", async (request, response) => {
  try {
    const identity = accessControl.fromRequest(request);
    subscriptionStore.consumeGuestWave(identity.userId, identity.guestToken);
    response.json(await wave.next(request.params.id, waveAccess(request), waveOwner(request)));
  } catch (error) { sendWaveError(response, error); }
});

app.post("/api/v1/wave/sessions/:id/feedback", async (request, response) => {
  const input = waveFeedbackSchema.safeParse(request.body);
  if (!input.success) return void response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid wave feedback" } });
  try {
    response.json(await wave.feedback(request.params.id, input.data, waveAccess(request), waveOwner(request)));
  } catch (error) { sendWaveError(response, error); }
});

app.put("/api/v1/wave/sessions/:id/state", (request, response) => {
  const input = waveCheckpointSchema.safeParse(request.body);
  if (!input.success) return void response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid wave state" } });
  try {
    response.json(wave.checkpoint(request.params.id, input.data, waveOwner(request)));
  } catch (error) { sendWaveError(response, error); }
});

app.delete("/api/v1/wave/sessions/:id", (request, response) => {
  try { response.status(wave.stop(request.params.id, waveOwner(request)) ? 204 : 404).end(); }
  catch (error) { sendWaveError(response, error); }
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

function roomAccess(socket: import("socket.io").Socket, create = false) {
  const deviceId = socket.handshake.auth.deviceId;
  if (typeof deviceId !== "string") throw new Error("Войдите в аккаунт Resonance");
  let userId = typeof socket.data.subscriptionUserId === "string" ? socket.data.subscriptionUserId : undefined;
  if (!userId) {
    const authorization = socket.handshake.auth.authorization;
    if (typeof authorization !== "string") throw new Error("Войдите в аккаунт Resonance");
    const identity = accessControl.identity({ authorization });
    if (!identity.userId) throw new Error("Войдите в аккаунт Resonance");
    userId = identity.userId;
    // The JWT authenticates the handshake. The live socket keeps only the user
    // identity; subscription/device rights are still rechecked every 30 seconds.
    // A new transport handshake must present a fresh valid access token.
    socket.data.subscriptionUserId = userId;
  }
  subscriptionStore.require(create ? "rooms.create" : "rooms.join", userId);
  socket.data.userId = userId;
  subscriptionStore.touchDevice(userId, deviceId);
}
io.use((socket, next) => { try { roomAccess(socket); next(); } catch { next(new Error("Для комнат нужна действующая подписка и вход в аккаунт")); } });
io.on("connection", (socket) => {
  registerRoomHandlers(io, socket, create => roomAccess(socket, create));
  const timer = setInterval(() => { try { roomAccess(socket); } catch { socket.disconnect(true); } }, 30_000);
  socket.once("disconnect", () => clearInterval(timer));
});

function waveOwner(request: express.Request) {
  const identity = accessControl.fromRequest(request);
  const tier = subscriptionStore.snapshot(identity.userId, identity.guestToken).tier;
  return `${identity.userId ?? hashSecret(identity.guestToken ?? "")}:${tier}`;
}

function sendGatewayError(response: express.Response, error: unknown) {
  if (error instanceof SubscriptionError || error instanceof AccountError) { accessError(response, error); return; }
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
  const result: Partial<Record<"soundcloud" | "yandex", ProviderAccess>> = {};
  for (const provider of ["soundcloud", "yandex"] as const) {
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

function optionalNumber(value?: string) {
  if (!value?.trim()) return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

httpServer.listen(port, () => {
  console.log(`Stellarify API listening on http://localhost:${port}`);
});
