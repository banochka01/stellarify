import assert from "node:assert/strict";
import { createServer, type Server } from "node:http";
import { after, before, test } from "node:test";
import express from "express";
import { FixedWindowRateLimiter } from "./client-reports.js";
import {
  MIN_SAMPLE_BYTES,
  RecognitionError,
  RecognitionService,
  createRecognizeRouter,
  isAllowedSampleType,
  parseAuddResult
} from "./recognize.js";

const TOKEN = "a".repeat(40);
const auddSuccess = {
  status: "success",
  result: {
    artist: "Imagine Dragons",
    title: "Warriors",
    album: "Warriors",
    release_date: "2014-09-18",
    spotify: {
      id: "1lgN0A2Vki2FTON5PYq42m",
      duration_ms: 170_000,
      external_ids: { isrc: "USUM71414145" },
      album: { images: [{ url: "https://i.scdn.co/image/abc" }] }
    }
  }
};

type Call = { url: string; body: FormData };
const calls: Call[] = [];
let upstream: unknown = auddSuccess;

const fakeFetch = async (url: string, init?: RequestInit) => {
  calls.push({ url, body: init?.body as FormData });
  return new Response(JSON.stringify(upstream), { status: 200, headers: { "content-type": "application/json" } });
};

let server: Server;
let baseUrl: string;
let disabledUrl: string;

before(async () => {
  const app = express();
  app.use(express.json());
  const authenticate = (token: string) => {
    if (token !== TOKEN) throw new Error("bad session");
    return { id: "user-1" };
  };
  app.use("/on", createRecognizeRouter(
    new RecognitionService("secret-token", fakeFetch),
    authenticate,
    new FixedWindowRateLimiter(3, 60_000)
  ));
  app.use("/off", createRecognizeRouter(new RecognitionService(undefined, fakeFetch), authenticate));
  server = createServer(app);
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  assert(address && typeof address === "object");
  baseUrl = `http://127.0.0.1:${address.port}/on`;
  disabledUrl = `http://127.0.0.1:${address.port}/off`;
});

after(async () => {
  await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
});

const sample = (bytes = MIN_SAMPLE_BYTES + 10) => new Uint8Array(new ArrayBuffer(bytes)).fill(7);
const post = (url: string, body: Uint8Array<ArrayBuffer>, headers: Record<string, string> = {}) =>
  fetch(url, {
    method: "POST",
    body,
    headers: { authorization: `Bearer ${TOKEN}`, "content-type": "audio/mp4", ...headers }
  });

test("status reports whether recognition is configured", async () => {
  assert.deepEqual(await (await fetch(`${baseUrl}/status`)).json(), { available: true, sampleSeconds: 8 });
  assert.deepEqual(await (await fetch(`${disabledUrl}/status`)).json(), { available: false, sampleSeconds: 8 });
});

test("without AUDD_API_TOKEN the endpoint is disabled and never calls upstream", async () => {
  const before = calls.length;
  const response = await post(disabledUrl, sample());
  assert.equal(response.status, 503);
  assert.equal(calls.length, before);
  assert.equal(RecognitionService.fromEnvironment(fakeFetch, {}).available, false);
  assert.equal(RecognitionService.fromEnvironment(fakeFetch, { AUDD_API_TOKEN: " x " }).available, true);
});

test("requires an account session", async () => {
  const response = await post(baseUrl, sample(), { authorization: "Bearer nope" });
  assert.equal(response.status, 401);
  const missing = await fetch(baseUrl, { method: "POST", body: sample(), headers: { "content-type": "audio/mp4" } });
  assert.equal(missing.status, 401);
});

test("forwards the sample to AudD and returns the parsed track", async () => {
  upstream = auddSuccess;
  const response = await post(baseUrl, sample());
  assert.equal(response.status, 200);
  const body = await response.json() as { track: Record<string, unknown> };
  assert.equal(body.track.title, "Warriors");
  assert.equal(body.track.artist, "Imagine Dragons");
  assert.equal(body.track.isrc, "USUM71414145");
  assert.equal(body.track.durationMs, 170_000);
  const call = calls.at(-1)!;
  assert.equal(call.url, "https://api.audd.io/");
  assert.equal(call.body.get("api_token"), "secret-token");
  const file = call.body.get("file");
  assert(file instanceof Blob);
  assert.equal(file.size, MIN_SAMPLE_BYTES + 10);
});

test("rejects bad formats and too short samples", async () => {
  assert.equal((await post(baseUrl, sample(), { "content-type": "text/plain" })).status, 415);
  assert.equal((await post(baseUrl, sample(100))).status, 400);
});

test("rate limits per account", async () => {
  // Лимитер на 3 запроса уже частично израсходован предыдущими тестами.
  let limited = false;
  for (let attempt = 0; attempt < 5; attempt++) {
    if ((await post(baseUrl, sample())).status === 429) limited = true;
  }
  assert.equal(limited, true);
});

test("parses AudD results: no match, errors and unsafe fields", () => {
  assert.equal(parseAuddResult({ status: "success", result: null }), null);
  assert.throws(() => parseAuddResult({ status: "error", error: { error_code: 900 } }), RecognitionError);
  const track = parseAuddResult({
    status: "success",
    result: { artist: "A", title: "B", spotify: { id: "../../etc", album: { images: [{ url: "http://insecure" }] } } }
  });
  assert.deepEqual(track, { title: "B", artist: "A" });
});

test("accepts common audio content types only", () => {
  assert.equal(isAllowedSampleType("audio/mp4"), true);
  assert.equal(isAllowedSampleType("audio/wav; codecs=1"), true);
  assert.equal(isAllowedSampleType("application/json"), false);
  assert.equal(isAllowedSampleType(undefined), false);
});

test("upstream failures surface as 502 without leaking details", async () => {
  const failing = new RecognitionService("t", async () => new Response("boom", { status: 500 }));
  await assert.rejects(failing.recognize(Buffer.alloc(MIN_SAMPLE_BYTES + 1)), (error: unknown) =>
    error instanceof RecognitionError && error.code === "UPSTREAM");
});

test("global daily AudD quota resets on the next UTC day", async () => {
  let now = Date.parse("2026-10-13T10:00:00Z");
  let upstreamCalls = 0;
  const service = new RecognitionService(
    "t",
    async () => {
      upstreamCalls += 1;
      return new Response(JSON.stringify({ status: "success", result: null }), { status: 200 });
    },
    undefined,
    undefined,
    2,
    () => now
  );
  const audio = Buffer.alloc(MIN_SAMPLE_BYTES + 1);
  assert.equal(await service.recognize(audio), null);
  assert.equal(await service.recognize(audio), null);
  await assert.rejects(service.recognize(audio), (error: unknown) =>
    error instanceof RecognitionError && error.code === "DAILY_LIMIT");
  assert.equal(upstreamCalls, 2);
  now = Date.parse("2026-10-14T00:00:01Z");
  assert.equal(await service.recognize(audio), null);
  assert.equal(
    (RecognitionService.fromEnvironment(fakeFetch, { AUDD_API_TOKEN: "x", AUDD_DAILY_LIMIT: "0" }) as unknown as { dailyLimit: number }).dailyLimit,
    0
  );
});
