import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";
import express from "express";
import { ProxyAgent } from "undici";
import { pickYoutubeFormat, YoutubeStreamService } from "./youtube-stream.js";

test("picks H.264 MP4 up to 720p and skips audio-only and WebM", () => {
  const format = pickYoutubeFormat([
    { itag: 251, url: "a", mimeType: "audio/webm; codecs=\"opus\"" },
    { itag: 248, url: "b", mimeType: "video/webm; codecs=\"vp9\"", height: 1080 },
    { itag: 137, url: "c", mimeType: "video/mp4; codecs=\"avc1.640028\"", height: 1080 },
    { itag: 136, url: "d", mimeType: "video/mp4; codecs=\"avc1.4d401f\"", height: 720 },
    { itag: 18, url: "e", mimeType: "video/mp4; codecs=\"avc1.42001E, mp4a.40.2\"", height: 360 }
  ]);
  assert.equal(format?.itag, 136);
  assert.equal(pickYoutubeFormat([{ itag: 251, url: "a", mimeType: "audio/webm" }]), undefined);
});

test("relays only allowed ids, with range, and refreshes a stale link", async () => {
  let resolves = 0;
  const calls: string[] = [];
  const fakeFetch = (async (input: string | URL, init?: { headers?: Record<string, string> }) => {
    const url = String(input);
    if (url.includes("youtubei/v1/player")) {
      resolves++;
      return new Response(JSON.stringify({
        playabilityStatus: { status: "OK" },
        streamingData: { adaptiveFormats: [
          { itag: 136, url: `https://video.test/v${resolves}`, mimeType: "video/mp4; codecs=\"avc1\"", height: 720 }
        ] }
      }), { status: 200 });
    }
    calls.push(`${url} ${init?.headers?.range}`);
    if (url.endsWith("/v1")) return new Response("gone", { status: 403 });
    return new Response("abcd", {
      status: 206,
      headers: { "content-type": "video/mp4", "content-range": "bytes 0-3/10", "content-length": "4" }
    });
  }) as unknown as typeof import("undici").fetch;
  const service = new YoutubeStreamService(new ProxyAgent("http://127.0.0.1:9"), fakeFetch);
  const app = express();
  app.get("/v/:id", (request, response) => void service.relay(String(request.params.id), request, response));
  const server = createServer(app).listen(0);
  try {
    const { port } = server.address() as { port: number };
    const denied = await fetch(`http://127.0.0.1:${port}/v/dQw4w9WgXcQ`);
    assert.equal(denied.status, 404);

    service.allow("dQw4w9WgXcQ");
    const ok = await fetch(`http://127.0.0.1:${port}/v/dQw4w9WgXcQ`, { headers: { range: "bytes=0-3" } });
    assert.equal(ok.status, 206);
    assert.equal(await ok.text(), "abcd");
    assert.equal(ok.headers.get("content-range"), "bytes 0-3/10");
    assert.equal(resolves, 2);
    assert.deepEqual(calls, ["https://video.test/v1 bytes=0-3", "https://video.test/v2 bytes=0-3"]);
  } finally {
    server.close();
  }
});
