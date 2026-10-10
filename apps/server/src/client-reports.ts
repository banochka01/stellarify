import { appendFile, mkdir, rename, stat } from "node:fs/promises";
import { dirname } from "node:path";
import { Router } from "express";
import { z } from "zod";

export const clientReportSchema = z.object({
  kind: z.enum(["crash", "playback", "network"]),
  message: z.string().trim().min(1).max(500),
  stack: z.string().max(4_000).optional(),
  appVersion: z.string().trim().max(32).optional(),
  platform: z.string().trim().max(32).optional(),
  provider: z.string().trim().max(32).optional(),
  context: z
    .record(z.string().max(64), z.union([z.string().max(200), z.number(), z.boolean()]))
    .refine((value) => Object.keys(value).length <= 20, "too many context keys")
    .optional()
});

export type ClientReport = z.infer<typeof clientReportSchema>;

export class FixedWindowRateLimiter {
  private readonly hits = new Map<string, { start: number; count: number }>();

  constructor(
    private readonly limit: number,
    private readonly windowMs: number,
    private readonly now: () => number = Date.now,
    private readonly maxKeys = 10_000
  ) {}

  allow(key: string): boolean {
    const now = this.now();
    const entry = this.hits.get(key);
    if (!entry || now - entry.start >= this.windowMs) {
      if (!entry && this.hits.size >= this.maxKeys) this.prune(now);
      this.hits.set(key, { start: now, count: 1 });
      return true;
    }
    if (entry.count >= this.limit) return false;
    entry.count += 1;
    return true;
  }

  private prune(now: number) {
    for (const [key, entry] of this.hits) {
      if (now - entry.start >= this.windowMs) this.hits.delete(key);
    }
    if (this.hits.size >= this.maxKeys) this.hits.clear();
  }
}

/** Appends reports as JSON lines and rotates once the file exceeds [maxBytes]. */
export class ClientReportStore {
  private queue: Promise<void> = Promise.resolve();
  readonly recent: Array<ClientReport & { receivedAt: string }> = [];

  constructor(
    private readonly path: string | undefined,
    private readonly maxBytes = 5 * 1024 * 1024,
    private readonly keepRecent = 200
  ) {}

  add(report: ClientReport, receivedAt = new Date()) {
    const entry = { ...report, receivedAt: receivedAt.toISOString() };
    this.recent.push(entry);
    if (this.recent.length > this.keepRecent) this.recent.shift();
    if (!this.path) return Promise.resolve();
    const path = this.path;
    this.queue = this.queue
      .then(async () => {
        await mkdir(dirname(path), { recursive: true });
        const size = await stat(path).then((info) => info.size, () => 0);
        if (size > this.maxBytes) await rename(path, `${path}.1`).catch(() => undefined);
        await appendFile(path, `${JSON.stringify(entry)}\n`, "utf8");
      })
      .catch((error) => {
        console.error("Client report write failed", error instanceof Error ? error.message : error);
      });
    return this.queue;
  }
}

export function createClientReportRouter(
  store: ClientReportStore,
  limiter = new FixedWindowRateLimiter(30, 10 * 60_000)
) {
  const router = Router();
  router.post("/", (request, response) => {
    if (!limiter.allow(request.ip || "unknown")) {
      response.status(429).json({ error: { code: "RATE_LIMITED", message: "Too many reports" } });
      return;
    }
    const input = clientReportSchema.safeParse(request.body);
    if (!input.success) {
      response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid report" } });
      return;
    }
    void store.add(input.data);
    response.status(202).json({ accepted: true });
  });
  return router;
}
