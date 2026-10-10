import { createHash, timingSafeEqual } from "node:crypto";
import express from "express";
import { z } from "zod";
import { AccountError, type AccountStore, type AccountUser } from "./account-store.js";
import { ProviderGatewayError, type ProviderAccess } from "./provider-gateway.js";
import { MigrationError, type MigrationService } from "./migration.js";

const sourceEnum = z.enum(["yandex", "spotify", "vk"]);
const targetEnum = z.enum(["yandex", "spotify", "vk", "soundcloud", "youtube"]);

const startSchema = z.object({
  source: sourceEnum,
  target: targetEnum
}).strict();

const httpsUrl = z.string().url().max(2_048).refine((value) => {
  const url = new URL(value);
  return url.protocol === "https:" && !url.username && !url.password;
}, "Expected a credential-free HTTPS URL");

const replaceSchema = z.object({
  track: z.object({
    id: z.string().trim().min(1).max(300),
    title: z.string().trim().min(1).max(500),
    artist: z.string().trim().min(1).max(500),
    album: z.string().trim().max(500).optional(),
    durationMs: z.number().int().min(0).max(24 * 60 * 60 * 1_000).optional(),
    artworkUrl: httpsUrl.optional(),
    externalUrl: httpsUrl,
    isrc: z.string().trim().max(20).optional()
  }).strict(),
  provider: targetEnum.optional()
}).strict();

type Authenticate = Pick<AccountStore, "authenticate">;

/**
 * "Переезд" endpoints. Provider tokens travel in headers per request
 * (X-Source-Token / X-Target-Token) and are kept in memory only while a job runs.
 */
export function createMigrationRouter(
  service: MigrationService,
  accounts: Authenticate,
  options: { adminToken?: string } = {}
) {
  const router = express.Router();
  router.use((_request, response, next) => {
    response.setHeader("cache-control", "private, no-store");
    next();
  });

  router.get("/metrics", (request, response) => {
    const expected = options.adminToken?.trim();
    const provided = request.header("x-admin-token")?.trim() ?? "";
    if (!expected || !safeEqual(provided, expected)) {
      response.status(404).json({ error: { code: "NOT_FOUND", message: "Not found" } });
      return;
    }
    response.json({ providers: service.metrics() });
  });

  router.use((request, response, next) => {
    const match = request.header("authorization")?.match(/^Bearer ([A-Za-z0-9_-]{30,256})$/u);
    if (!match?.[1]) {
      response.status(401).json({ error: { code: "AUTH_REQUIRED", message: "Войдите в Resonance ID" } });
      return;
    }
    try {
      response.locals.accountUser = accounts.authenticate(match[1]);
      next();
    } catch (error) {
      sendError(response, error);
    }
  });

  const user = (response: express.Response) => (response.locals.accountUser as AccountUser).id;

  router.get("/", (_request, response) => {
    response.json({ jobs: service.list(user(response)) });
  });

  const start = (kind: "full" | "resync") => (request: express.Request, response: express.Response) => {
    const input = startSchema.safeParse(request.body);
    if (!input.success) return invalid(response, "Выберите, откуда и куда переносить музыку");
    try {
      const job = service.start(user(response), { ...input.data, kind }, tokens(request));
      response.status(202).json({ job: service.job(user(response), job.id) });
    } catch (error) {
      sendError(response, error);
    }
  };
  router.post("/", start("full"));
  router.post("/resync", start("resync"));

  router.get("/:id", (request, response) => {
    try {
      response.json({ job: service.job(user(response), String(request.params.id)) });
    } catch (error) {
      sendError(response, error);
    }
  });

  router.get("/:id/report", (request, response) => {
    try {
      response.json(service.report(user(response), String(request.params.id)));
    } catch (error) {
      sendError(response, error);
    }
  });

  router.post("/:id/resume", (request, response) => {
    try {
      response.status(202).json({ job: service.resume(user(response), String(request.params.id), tokens(request)) });
    } catch (error) {
      sendError(response, error);
    }
  });

  router.get("/:id/items/:itemId/candidates", async (request, response) => {
    const query = typeof request.query.q === "string" ? request.query.q.slice(0, 200) : undefined;
    try {
      const candidates = await service.candidates(
        user(response),
        String(request.params.id),
        Number(request.params.itemId),
        query,
        tokens(request).target
      );
      response.json({ candidates });
    } catch (error) {
      sendError(response, error);
    }
  });

  router.post("/:id/items/:itemId/confirm", (request, response) => {
    try {
      response.json({ item: service.confirm(user(response), String(request.params.id), Number(request.params.itemId)) });
    } catch (error) {
      sendError(response, error);
    }
  });

  router.post("/:id/items/:itemId/replace", (request, response) => {
    const input = replaceSchema.safeParse(request.body);
    if (!input.success) return invalid(response, "Некорректный трек для замены");
    try {
      const job = service.job(user(response), String(request.params.id));
      const item = service.replace(user(response), job.id, Number(request.params.itemId), {
        ...input.data.track,
        provider: input.data.provider ?? job.target
      });
      response.json({ item });
    } catch (error) {
      sendError(response, error);
    }
  });

  return router;
}

function tokens(request: express.Request): { source?: ProviderAccess; target?: ProviderAccess } {
  const read = (name: string) => {
    const value = request.header(name)?.trim();
    if (!value || value.length > 4096 || /[\r\n]/.test(value)) return undefined;
    return { token: value, cacheScope: createHash("sha256").update(value).digest("hex") };
  };
  const source = read("x-source-token") ?? read("x-provider-token");
  const target = read("x-target-token");
  return { ...(source ? { source } : {}), ...(target ? { target } : {}) };
}

function sendError(response: express.Response, error: unknown) {
  if (error instanceof MigrationError || error instanceof AccountError || error instanceof ProviderGatewayError) {
    response.status(error.status).json({ error: { code: error.code, message: error.message } });
    return;
  }
  console.error("Migration request failed", error);
  response.status(500).json({ error: { code: "MIGRATION_ERROR", message: "Ошибка переноса" } });
}

function invalid(response: express.Response, message: string) {
  response.status(400).json({ error: { code: "INVALID_REQUEST", message } });
}

function safeEqual(left: string, right: string) {
  const a = createHash("sha256").update(left).digest();
  const b = createHash("sha256").update(right).digest();
  return timingSafeEqual(a, b);
}
