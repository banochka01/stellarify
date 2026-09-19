import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";
import test from "node:test";
import express from "express";
import { ClipService, clipSchema, createClipRouter, builtInClips, type Clip } from "./clips.js";

const clip = (overrides: Partial<Clip> = {}): Clip => ({
  id: "clip-1", title: "Signal", artist: "Artist", kind: "musicVideo",
  url: "https://cdn.example.com/clip.mp4", source: "Catalog",
  sourceUrl: "https://example.com/clip", offsetMs: 0, playback: "direct", ...overrides
});
const json = (body: unknown) => new Response(JSON.stringify(body));

test("matches normalized title and artist, sorts music before ambient, excludes other songs", async () => {
  const service = new ClipService([
    clip({ kind: "ambient", url: "https://cdn.example.com/ambient.mp4" }),
    clip({ title: "SIGNAL!" }), clip({ artist: "Another artist", url: "https://cdn.example.com/wrong.mp4" })
  ]);
  const found = await service.find("signal", "artist");
  assert.equal(found.length, 2);
  assert.equal(found[0]?.kind, "musicVideo");
});

test("deduplicates URLs and coalesces concurrent requests", async () => {
  let calls = 0;
  const service = new ClipService([], ["https://provider.example/clips"], "", async (url) => {
    calls++;
    assert.equal(new URL(String(url)).searchParams.get("title"), "Signal");
    await new Promise((resolve) => setTimeout(resolve, 5));
    return json({ clips: [clip(), clip()] });
  });
  const results = await Promise.all([service.find("Signal", "Artist"), service.find("Signal", "Artist")]);
  assert.equal(results[0]?.length, 1);
  await service.find("Signal", "Artist");
  assert.equal(calls, 1);
});

test("unavailable provider does not prevent a working source", async () => {
  const service = new ClipService([], ["https://bad.example", "https://good.example"], "", async (url) => {
    if (String(url).includes("bad.example")) throw new Error("offline");
    return json({ clips: [clip()] });
  });
  assert.equal((await service.find("Signal", "Artist")).length, 1);
});

test("provider failure is retriable instead of cached as no match", async () => {
  let calls = 0;
  const service = new ClipService([], ["https://provider.example"], "", async () => {
    if (++calls === 1) return new Response("", { status: 503 });
    return json({ clips: [clip()] });
  });
  await assert.rejects(service.find("Signal", "Artist"));
  assert.equal((await service.find("Signal", "Artist")).length, 1);
});

test("empty config returns no video without network requests", async () => {
  const service = new ClipService([], [], "", async () => { throw new Error("unexpected request"); });
  assert.deepEqual(await service.find("Signal", "Artist"), []);
});

test("built-in footage remains available when custom providers fail", async () => {
  const service = new ClipService([], ["https://provider.example"], "invalid-key",
    async () => new Response("", { status: 503 }), builtInClips);
  const result = await service.find("Unknown song", "Unknown artist");
  assert.equal(result.length, 2);
  assert.ok(result.every((clip) => clip.kind === "ambient" && clipSchema.safeParse(clip).success));
});

test("rejects executable, credential-bearing and insecure media URLs", () => {
  for (const url of ["file:///etc/passwd", "http://example.com/a.mp4", "https://user:secret@example.com/a.mp4", "javascript:alert(1)"]) {
    assert.equal(clipSchema.safeParse(clip({ url })).success, false);
  }
  assert.throws(() => new ClipService([], ["http://provider.example"]));
});

test("rejects oversized provider response", async () => {
  const service = new ClipService([], ["https://provider.example"], "", async () => new Response("x".repeat(1024 * 1024 + 1)));
  await assert.rejects(service.find("Signal", "Artist"));
});

test("Pexels fallback uses server credentials, HD MP4, attribution and global cache", async () => {
  let calls = 0;
  const service = new ClipService([], [], "server-key", async (url, options) => {
    calls++;
    assert.equal(new URL(String(url)).hostname, "api.pexels.com");
    assert.equal((options?.headers as Record<string, string>).Authorization, "server-key");
    return json({ videos: [{ id: 7, url: "https://www.pexels.com/video/7/", user: { name: "Creator" },
      video_files: [
        { link: "https://videos.pexels.com/4k.mp4", file_type: "video/mp4", width: 3840 },
        { link: "https://videos.pexels.com/hd.mp4", file_type: "video/mp4", width: 1280 }
      ] }] });
  });
  const found = await service.find("Signal", "Artist");
  assert.equal(found[0]?.url, "https://videos.pexels.com/hd.mp4");
  assert.equal(found[0]?.kind, "ambient");
  assert.equal(found[0]?.source, "Creator · Pexels");
  assert.equal(JSON.stringify(found).includes("server-key"), false);
  await service.find("Different", "Song");
  assert.equal(calls, 1);
});

test("clips route validates queries and returns the client contract", async (t) => {
  const app = express();
  app.use("/api/v1/clips", createClipRouter(new ClipService([clip()])));
  const server = createServer(app).listen(0, "127.0.0.1");
  t.after(() => server.close());
  await once(server, "listening");
  const address = server.address();
  assert.ok(address && typeof address !== "string");
  const base = `http://127.0.0.1:${address.port}/api/v1/clips`;
  assert.equal((await fetch(base)).status, 400);
  const response = await fetch(`${base}?title=Signal&artist=Artist`);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).clips[0].id, "clip-1");
});

test("Apple source returns a directly playable official preview", async () => {
  const service = new ClipService([], [], "", async (input) => {
    const url = new URL(String(input));
    assert.equal(url.hostname, "itunes.apple.com");
    assert.equal(url.searchParams.get("entity"), "musicVideo");
    return json({ results: [{
      trackId: 42,
      trackName: "Signal (Official Video)",
      artistName: "Artist",
      previewUrl: "https://video-ssl.itunes.apple.com/signal.m4v",
      trackViewUrl: "https://music.apple.com/us/music-video/signal/42"
    }] });
  }, [], { appleCountries: ["us"] });
  const found = await service.find("Signal", "Artist");
  assert.equal(found[0]?.kind, "preview");
  assert.equal(found[0]?.playback, "direct");
  assert.match(found[0]?.url ?? "", /signal\.m4v$/);
});

test("Apple source combines playable previews from several storefronts", async () => {
  const countries: string[] = [];
  const service = new ClipService([], [], "", async (input) => {
    const url = new URL(String(input));
    const country = url.searchParams.get("country")!;
    countries.push(country);
    return json({ results: [{
      trackId: country === "us" ? 1 : 2, trackName: "Signal", artistName: "Artist",
      previewUrl: `https://video-ssl.itunes.apple.com/${country}.m4v`,
      trackViewUrl: `https://music.apple.com/${country}/music-video/signal/1`
    }] });
  }, [], { appleCountries: ["us", "gb"] });
  const found = await service.find("Signal", "Artist");
  assert.deepEqual(countries.sort(), ["gb", "us"]);
  assert.equal(found.filter((item) => item.kind === "preview").length, 2);
  assert.ok(found.every((item) => item.playback === "direct"));
});

test("Dailymotion results are discoverable without pretending watch pages are media", async () => {
  const service = new ClipService([], [], "", async () => json({ list: [{
    id: "x1", title: "Artist - Signal (Official Video)",
    url: "https://www.dailymotion.com/video/x1", channel: "music"
  }] }), [], { dailymotion: true });
  const found = await service.find("Signal", "Artist");
  assert.equal(found[0]?.source, "Dailymotion");
  assert.equal(found[0]?.playback, "external");
  assert.equal(found[0]?.url, undefined);
});

test("external references cannot masquerade as direct clips", () => {
  assert.equal(clipSchema.safeParse({ ...clip(), url: undefined }).success, false);
  assert.equal(clipSchema.safeParse({ ...clip(), url: undefined, playback: "external" }).success, true);
});
