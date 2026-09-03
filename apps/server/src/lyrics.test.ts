import assert from "node:assert/strict";
import test from "node:test";
import { LyricsService, parseLrc } from "./lyrics.js";

test("parses timestamps, offset and duplicate LRC stamps", () => {
  assert.deepEqual(
    parseLrc("[offset:100]\n[00:01.20][00:02.345]Hello\n[00:03]World"),
    [
      { startMs: 1_300, text: "Hello" },
      { startMs: 2_445, text: "Hello" },
      { startMs: 3_100, text: "World" }
    ]
  );
});

test("returns synchronized lyrics and caches the result", async () => {
  let calls = 0;
  const service = new LyricsService(async () => {
    calls += 1;
    return Response.json({
      id: 42,
      trackName: "Night Drive",
      artistName: "Resonance",
      albumName: "Flow",
      duration: 180,
      instrumental: false,
      plainLyrics: "First\nSecond",
      syncedLyrics: "[00:01.00]First\n[00:05.50]Second"
    });
  });

  const query = { title: "Night Drive", artist: "Resonance", durationMs: 180_000 };
  const first = await service.find(query);
  const second = await service.find(query);
  assert.equal(calls, 1);
  assert.equal(first?.synced, true);
  assert.deepEqual(first?.lines, [
    { startMs: 1_000, text: "First" },
    { startMs: 5_500, text: "Second" }
  ]);
  assert.deepEqual(second, first);
});

test("falls back to search and prefers an exact synchronized match", async () => {
  const service = new LyricsService(async input => {
    const url = new URL(String(input));
    if (url.pathname === "/api/get") return new Response(null, { status: 404 });
    return Response.json([
      { id: 1, trackName: "Other", artistName: "Artist", instrumental: false, plainLyrics: "No" },
      { id: 2, trackName: "Track", artistName: "Artist", instrumental: false, syncedLyrics: "[00:01]Yes" }
    ]);
  });
  const result = await service.find({ title: "Track", artist: "Artist" });
  assert.equal(result?.id, 2);
  assert.equal(result?.synced, true);
});

test("does not return an unrelated search result", async () => {
  const service = new LyricsService(async input => {
    const url = new URL(String(input));
    if (url.pathname === "/api/get") return new Response(null, { status: 404 });
    return Response.json([
      { id: 9, trackName: "Different Song", artistName: "Someone Else", instrumental: false, plainLyrics: "No" }
    ]);
  });
  assert.equal(await service.find({ title: "Track", artist: "Artist" }), null);
});
