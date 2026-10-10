import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { ClientReportStore, FixedWindowRateLimiter, clientReportSchema } from "./client-reports.js";
import { ServiceHealthMonitor, overallState } from "./service-health.js";

test("reports ok, down, timeout and unconfigured probes and caches results", async () => {
  let calls = 0;
  const monitor = new ServiceHealthMonitor([
    { id: "a", label: "A", configured: true, check: async () => { calls += 1; } },
    { id: "b", label: "B", configured: true, check: async () => { throw new Error("secret token in url"); } },
    { id: "c", label: "C", configured: true, check: () => new Promise(() => undefined) },
    { id: "d", label: "D", configured: false, check: async () => undefined }
  ], { timeoutMs: 20 });
  const first = await monitor.snapshot();
  const byId = (id: string) => first.services.find((service) => service.id === id)!;
  assert.equal(byId("a").state, "ok");
  assert.equal(byId("b").state, "down");
  assert.equal(byId("b").error, "unavailable");
  assert.equal(byId("c").error, "timeout");
  assert.equal(byId("d").state, "unconfigured");
  assert.equal(first.overall, "degraded");
  await monitor.snapshot();
  assert.equal(calls, 1);
});

test("overall state", () => {
  const at = "x";
  assert.equal(overallState([]), "unconfigured");
  assert.equal(overallState([{ id: "a", label: "a", state: "down", checkedAt: at }]), "down");
  assert.equal(overallState([{ id: "a", label: "a", state: "ok", checkedAt: at }]), "ok");
});

test("rate limiter allows a fixed number of hits per window", () => {
  let now = 0;
  const limiter = new FixedWindowRateLimiter(2, 1_000, () => now);
  assert.equal(limiter.allow("ip"), true);
  assert.equal(limiter.allow("ip"), true);
  assert.equal(limiter.allow("ip"), false);
  assert.equal(limiter.allow("other"), true);
  now = 1_000;
  assert.equal(limiter.allow("ip"), true);
});

test("validates and stores client reports as JSON lines", async () => {
  assert.equal(clientReportSchema.safeParse({ kind: "crash", message: "" }).success, false);
  assert.equal(clientReportSchema.safeParse({ kind: "other", message: "x" }).success, false);
  const report = clientReportSchema.parse({ kind: "playback", message: "boom", provider: "yandex", context: { code: 3 } });
  const path = join(await mkdtemp(join(tmpdir(), "reports-")), "r.jsonl");
  const store = new ClientReportStore(path);
  await store.add(report, new Date(0));
  const line = JSON.parse((await readFile(path, "utf8")).trim());
  assert.equal(line.message, "boom");
  assert.equal(line.receivedAt, "1970-01-01T00:00:00.000Z");
  assert.equal(store.recent.length, 1);
});
