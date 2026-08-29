import { createHash } from "node:crypto";
import express from "express";
import { z } from "zod";
import {
  AccountError,
  AccountStore,
  type AccountUser,
  type LibraryOperation
} from "./account-store.js";

const credentialsSchema = z.object({
  email: z.string().trim().toLowerCase().email().max(254),
  password: z.string().min(10).max(128),
  deviceName: z.string().trim().min(1).max(80).default("Resonance")
}).strict();

const refreshSchema = z.object({
  refreshToken: z.string().min(40).max(256),
  deviceName: z.string().trim().min(1).max(80).default("Resonance")
}).strict();

const logoutSchema = z.object({ refreshToken: z.string().min(40).max(256) }).strict();

const safeHttpsUrl = z.string().url().max(2_048).refine((value) => {
  const url = new URL(value);
  return url.protocol === "https:" && !url.username && !url.password;
}, "Expected a credential-free HTTPS URL");

const sourceSchema = z.object({
  provider: z.enum(["youtube", "yandex", "soundcloud"]),
  externalId: z.string().trim().min(1).max(300),
  externalUrl: safeHttpsUrl,
  metadata: z.record(z.string(), z.unknown()).optional()
}).transform((source) => ({ ...source, metadata: {} }));

const trackSchema = z.object({
  id: z.string().trim().min(1).max(300),
  title: z.string().trim().min(1).max(500),
  normalizedTitle: z.string().trim().min(1).max(500),
  artist: z.string().trim().min(1).max(500),
  normalizedArtist: z.string().trim().min(1).max(500),
  album: z.string().trim().max(500).nullable().optional(),
  duration: z.number().int().min(0).max(24 * 60 * 60 * 1_000).nullable().optional(),
  artworkUrl: safeHttpsUrl.nullable().optional(),
  sources: z.array(sourceSchema).max(8),
  preferredProvider: z.enum(["youtube", "yandex", "soundcloud"]).nullable().optional()
}).strict();

const operationSchema = z.discriminatedUnion("type", [
  z.object({ id: z.string().uuid(), type: z.literal("favoriteUpsert"), track: trackSchema }).strict(),
  z.object({ id: z.string().uuid(), type: z.literal("favoriteDelete"), trackId: z.string().min(1).max(300) }).strict(),
  z.object({
    id: z.string().uuid(),
    type: z.literal("playlistUpsert"),
    playlistId: z.string().min(1).max(100),
    name: z.string().trim().min(1).max(120),
    createdAt: z.string().datetime()
  }).strict(),
  z.object({ id: z.string().uuid(), type: z.literal("playlistDelete"), playlistId: z.string().min(1).max(100) }).strict(),
  z.object({
    id: z.string().uuid(),
    type: z.literal("playlistTrackUpsert"),
    playlistId: z.string().min(1).max(100),
    track: trackSchema,
    position: z.number().int().min(0).max(100_000)
  }).strict(),
  z.object({
    id: z.string().uuid(),
    type: z.literal("playlistTrackDelete"),
    playlistId: z.string().min(1).max(100),
    trackId: z.string().min(1).max(300)
  }).strict()
]);

const operationsSchema = z.object({ operations: z.array(operationSchema).min(1).max(100) }).strict();

export function createAccountRouter(store: AccountStore) {
  const router = express.Router();
  const identityLimiter = new SlidingWindowLimiter(10, 15 * 60 * 1_000);
  const ipLimiter = new SlidingWindowLimiter(30, 15 * 60 * 1_000);

  router.use((_request, response, next) => {
    response.setHeader("cache-control", "private, no-store");
    next();
  });

  router.post("/register", async (request, response) => {
    const input = credentialsSchema.safeParse(request.body);
    if (!input.success) return invalid(response, "Укажите корректную почту и пароль не короче 10 символов");
    if (!allowCredentialsAttempt(request, input.data.email, identityLimiter, ipLimiter)) return limited(response);
    try {
      response.status(201).json(await store.register(input.data.email, input.data.password, input.data.deviceName));
    } catch (error) {
      accountError(response, error);
    }
  });

  router.post("/login", async (request, response) => {
    const input = credentialsSchema.safeParse(request.body);
    if (!input.success) return invalid(response, "Укажите корректную почту и пароль");
    if (!allowCredentialsAttempt(request, input.data.email, identityLimiter, ipLimiter)) return limited(response);
    try {
      response.json(await store.login(input.data.email, input.data.password, input.data.deviceName));
    } catch (error) {
      accountError(response, error);
    }
  });

  router.post("/refresh", (request, response) => {
    const input = refreshSchema.safeParse(request.body);
    if (!input.success) return invalid(response, "Некорректная сессия");
    try {
      response.json(store.refresh(input.data.refreshToken, input.data.deviceName));
    } catch (error) {
      accountError(response, error);
    }
  });

  router.post("/logout", (request, response) => {
    const input = logoutSchema.safeParse(request.body);
    if (!input.success) return invalid(response, "Некорректная сессия");
    store.logout(input.data.refreshToken);
    response.status(204).end();
  });

  router.use((request, response, next) => {
    const match = request.header("authorization")?.match(/^Bearer ([A-Za-z0-9_-]{30,256})$/u);
    if (!match?.[1]) {
      response.status(401).json({ error: { code: "AUTH_REQUIRED", message: "Войдите в аккаунт" } });
      return;
    }
    try {
      response.locals.accountUser = store.authenticate(match[1]);
      next();
    } catch (error) {
      accountError(response, error);
    }
  });

  router.get("/me", (_request, response) => {
    response.json({ user: response.locals.accountUser as AccountUser });
  });

  router.get("/library", (_request, response) => {
    const user = response.locals.accountUser as AccountUser;
    response.json({ library: store.getLibrary(user.id) });
  });

  router.post("/library/operations", (request, response) => {
    const input = operationsSchema.safeParse(request.body);
    if (!input.success) return invalid(response, "Некорректная операция синхронизации");
    const user = response.locals.accountUser as AccountUser;
    try {
      const library = store.applyOperations(user.id, input.data.operations as LibraryOperation[]);
      response.json({ library });
    } catch (error) {
      console.error("Account library synchronization failed", error);
      response.status(500).json({ error: { code: "SYNC_FAILED", message: "Не удалось синхронизировать медиатеку" } });
    }
  });

  return router;
}

function accountError(response: express.Response, error: unknown) {
  if (error instanceof AccountError) {
    response.status(error.status).json({ error: { code: error.code, message: error.message } });
    return;
  }
  console.error("Account request failed", error);
  response.status(500).json({ error: { code: "ACCOUNT_ERROR", message: "Ошибка аккаунта" } });
}

function invalid(response: express.Response, message: string) {
  response.status(400).json({ error: { code: "INVALID_REQUEST", message } });
}

function limited(response: express.Response) {
  response.setHeader("retry-after", "900");
  response.status(429).json({ error: { code: "RATE_LIMITED", message: "Слишком много попыток. Попробуйте позже" } });
}

function rateKey(request: express.Request, email: string) {
  return createHash("sha256").update(`${request.ip}:${email}`).digest("hex");
}

function allowCredentialsAttempt(
  request: express.Request,
  email: string,
  identityLimiter: SlidingWindowLimiter,
  ipLimiter: SlidingWindowLimiter
) {
  const ip = request.ip ?? request.socket.remoteAddress ?? "unknown";
  const ipKey = createHash("sha256").update(ip).digest("hex");
  return ipLimiter.allow(ipKey) && identityLimiter.allow(rateKey(request, email));
}

class SlidingWindowLimiter {
  readonly #attempts = new Map<string, number[]>();
  constructor(readonly limit: number, readonly windowMs: number) {}

  allow(key: string) {
    const cutoff = Date.now() - this.windowMs;
    const attempts = (this.#attempts.get(key) ?? []).filter((value) => value > cutoff);
    if (attempts.length >= this.limit) {
      this.#attempts.set(key, attempts);
      return false;
    }
    attempts.push(Date.now());
    this.#attempts.set(key, attempts);
    if (this.#attempts.size > 10_000) {
      for (const [candidate, values] of this.#attempts) {
        if (values.every((value) => value <= cutoff)) this.#attempts.delete(candidate);
      }
    }
    return true;
  }
}
