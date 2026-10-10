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

/**
 * Reports come from untrusted clients and may carry stream URLs, provider
 * tokens or e-mails inside exception text. Strip them before storing.
 */
export function scrubReportText(value: string): string {
  return value
    .replace(/[a-z][a-z0-9+.-]*:\/\/[^\s"'<>]+/giu, "[url]")
    .replace(/[\w.+-]+@[\w-]+(?:\.[\w-]+)+/gu, "[email]")
    .replace(/\b(bearer|oauth|token|access_token|api_key|key|password|secret)(\s*[:=]\s*|\s+)[^\s,;&"']+/giu, "$1$2[redacted]")
    .replace(/\b[A-Za-z0-9_\-]{32,}\b/gu, "[redacted]")
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/gu, "");
}

export function scrubReport(report: ClientReport): ClientReport {
  return {
    ...report,
    message: scrubReportText(report.message),
    ...(report.stack !== undefined ? { stack: scrubReportText(report.stack) } : {}),
    ...(report.context
      ? {
          context: Object.fromEntries(Object.entries(report.context).map(([key, value]) =>
            [scrubReportText(key), typeof value === "string" ? scrubReportText(value) : value]))
        }
      : {})
  };
}

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
    void store.add(scrubReport(input.data));
    response.status(202).json({ accepted: true });
  });
  return router;
}
