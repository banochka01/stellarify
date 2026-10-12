import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";
import type express from "express";
import type { z } from "zod";
import { FixedWindowRateLimiter } from "./client-reports.js";

/** Typed API failure rendered as `{ error: { code, message } }`. */
export class ApiError extends Error {
  constructor(readonly code: string, message: string, readonly status = 400) {
    super(message);
  }
}

/** Resolves the Resonance account behind a request; throws on a bad token, `undefined` for guests. */
export type Authenticate = (request: express.Request) => string | undefined;

type Handler = (request: express.Request, response: express.Response) => unknown;

export function handle(fn: Handler) {
  return async (request: express.Request, response: express.Response) => {
    try {
      const result = await fn(request, response);
      if (result !== undefined && !response.headersSent) response.json(result);
    } catch (error) {
      sendApiError(response, error);
    }
  };
}

export function sendApiError(response: express.Response, error: unknown) {
  if (response.headersSent) return;
  const candidate = error as { code?: unknown; status?: unknown; message?: unknown };
  if (
    error instanceof Error &&
    typeof candidate.code === "string" &&
    typeof candidate.status === "number" &&
    candidate.status >= 400 && candidate.status < 600
  ) {
    if (candidate.status === 429) response.setHeader("retry-after", "60");
    response.status(candidate.status).json({ error: { code: candidate.code, message: error.message } });
    return;
  }
  console.error("API request failed", error);
  response.status(500).json({ error: { code: "INTERNAL_ERROR", message: "Внутренняя ошибка сервера" } });
}

export function requireUser(authenticate: Authenticate, request: express.Request) {
  const userId = authenticate(request);
  if (!userId) throw new ApiError("AUTH_REQUIRED", "Войдите в аккаунт", 401);
  return userId;
}

export function parse<T extends z.ZodType>(schema: T, value: unknown, message = "Некорректный запрос"): z.infer<T> {
  const result = schema.safeParse(value);
  if (!result.success) throw new ApiError("INVALID_REQUEST", message, 400);
  return result.data;
}

export class RateGate {
  readonly #limiter: FixedWindowRateLimiter;
  constructor(limit: number, windowMs: number, now: () => number = Date.now) {
    this.#limiter = new FixedWindowRateLimiter(limit, windowMs, now);
  }

  check(key: string) {
    if (!this.#limiter.allow(key)) throw new ApiError("RATE_LIMITED", "Слишком много запросов, попробуйте позже", 429);
  }
}

export const clientKey = (request: express.Request) => request.ip ?? request.socket.remoteAddress ?? "unknown";

/** Small TTL cache with bounded size and in-flight de-duplication. */
export class TtlCache<T> {
  readonly #values = new Map<string, { expiresAt: number; value: T }>();
  readonly #pending = new Map<string, Promise<T>>();
  constructor(readonly ttlMs: number, readonly maxEntries = 1_000, readonly now: () => number = Date.now) {}

  async get(key: string, load: () => Promise<T>): Promise<T> {
    const hit = this.#values.get(key);
    if (hit && hit.expiresAt > this.now()) return hit.value;
    const running = this.#pending.get(key);
    if (running) return running;
    const task = load().then((value) => {
      if (this.#values.size >= this.maxEntries) this.#values.delete(this.#values.keys().next().value!);
      this.#values.set(key, { expiresAt: this.now() + this.ttlMs, value });
      return value;
    }).finally(() => this.#pending.delete(key));
    this.#pending.set(key, task);
    return task;
  }

  clear() {
    this.#values.clear();
  }
}

/** Opens a SQLite database the same way as the room store (WAL on disk, `:memory:` in tests). */
export function openSqlite(path: string) {
  if (path !== ":memory:") mkdirSync(dirname(path), { recursive: true });
  const database = new DatabaseSync(path);
  database.exec("PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;");
  if (path !== ":memory:") database.exec("PRAGMA journal_mode = WAL;");
  return database;
}

export function transaction<T>(database: DatabaseSync, callback: () => T): T {
  database.exec("BEGIN IMMEDIATE");
  try {
    const result = callback();
    database.exec("COMMIT");
    return result;
  } catch (error) {
    database.exec("ROLLBACK");
    throw error;
  }
}
