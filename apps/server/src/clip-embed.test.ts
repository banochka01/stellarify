import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";
import test from "node:test";
import express from "express";
import { ClipOffsetStore, youtubeId } from "./clip-embed.js";
import { ClipService, createClipRouter, type Clip } from "./clips.js";

const youtubeClip: Clip = {
  id: "musicbrainz-1", title: "Signal", artist: "Artist", kind: "musicVideo", playback: "external",
  source: "MusicBrainz · YouTube", sourceUrl: "https://www.youtube.com/watch?v=dQw4w9WgXcQ", offsetMs: 0
};

async function serve(offsets = new ClipOffsetStore(":memory:")) {
  const app = express();
  app.use(express.json());
  app.use("/api/v1/clips", createClipRouter(new ClipService([youtubeClip]), undefined, offsets));
  const server = createServer(app).listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  assert(address && typeof address === "object");
  return { server, base: `http://127.0.0.1:${address.port}/api/v1/clips` };
}

test("extracts YouTube ids only from safe YouTube links", () => {
  assert.equal(youtubeId("https://youtu.be/dQw4w9WgXcQ"), "dQw4w9WgXcQ");
  assert.equal(youtubeId("https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=3"), "dQw4w9WgXcQ");
  assert.equal(youtubeId("https://www.youtube.com/embed/dQw4w9WgXcQ"), "dQw4w9WgXcQ");
  assert.equal(youtubeId("http://youtu.be/dQw4w9WgXcQ"), undefined);
  assert.equal(youtubeId("https://evil.example/watch?v=dQw4w9WgXcQ"), undefined);
  assert.equal(youtubeId("https://youtu.be/short"), undefined);
});

test("upgrades YouTube clips to embeds only for clients that ask for it", async () => {
  const { server, base } = await serve();
  try {
    const legacy = await (await fetch(`${base}?title=Signal&artist=Artist`)).json() as { clips: Clip[] };
    assert.equal(legacy.clips[0]!.playback, "external");
    assert.equal(legacy.clips[0]!.embed, undefined);
    const modern = await (await fetch(`${base}?title=Signal&artist=Artist&embed=youtube`)).json() as { clips: Clip[] };
    assert.equal(modern.clips[0]!.playback, "embed");
    assert.deepEqual(modern.clips[0]!.embed, { provider: "youtube", id: "dQw4w9WgXcQ" });
  } finally { server.close(); }
});

test("serves the embed page for valid ids only", async () => {
  const { server, base } = await serve();
  try {
    assert.equal((await fetch(`${base}/embed/youtube?v=bad`)).status, 400);
    const page = await fetch(`${base}/embed/youtube?v=dQw4w9WgXcQ`);
    assert.equal(page.status, 200);
    assert.match(page.headers.get("content-security-policy") ?? "", /frame-src https:\/\/www\.youtube\.com/);
    assert.match(await page.text(), /"dQw4w9WgXcQ"/);
  } finally { server.close(); }
});

test("publishes the median of crowd offset votes", async () => {
  const store = new ClipOffsetStore(":memory:");
  store.vote("track", "clip", "a", 1000);
  store.vote("track", "clip", "b", 1400);
  store.vote("track", "clip", "c", 90000);
  assert.equal(store.offsets("track").get("clip"), 1400);
  store.vote("track", "clip", "c", 1200);
  assert.equal(store.offsets("track").get("clip"), 1200);
  const { server, base } = await serve(store);
  try {
    const voted = await fetch(`${base}/offset`, { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ title: "Signal", artist: "Artist", clipId: "musicbrainz-1", offsetMs: 2500 }) });
    assert.deepEqual(await voted.json(), { clipId: "musicbrainz-1", offsetMs: 2500 });
    const listed = await (await fetch(`${base}?title=Signal&artist=Artist&embed=youtube`)).json() as { clips: Clip[] };
    assert.equal(listed.clips[0]!.offsetMs, 2500);
    const invalid = await fetch(`${base}/offset`, { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ title: "Signal", artist: "Artist", clipId: "x", offsetMs: 10_000_000 }) });
    assert.equal(invalid.status, 400);
  } finally { server.close(); }
});
