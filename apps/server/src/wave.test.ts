import assert from "node:assert/strict";
import test from "node:test";
import { WaveService, rerank, type WaveItem } from "./wave.js";
import type { ProviderGateway } from "./provider-gateway.js";
import type { YandexAdapter } from "./yandex.js";

function item(id: string, artist: string, album: string, score: number): WaveItem {
  return {
    id,
    title: `Track ${id}`,
    artist,
    album,
    externalUrl: `https://soundcloud.com/test/${id}`,
    provider: "soundcloud",
    lane: "adjacent",
    score
  };
}

test("rerank limits one artist to two tracks in a rolling ten", () => {
  const candidates = [
    ...Array.from({ length: 7 }, (_, index) => item(`p${index}`, "PHARAOH", `A${index}`, 1 - index / 100)),
    item("s1", "SALUKI", "S1", .8),
    item("s2", "SALUKI", "S2", .79),
    item("m1", "Mnogoznaal", "M1", .78)
  ];
  const result = rerank(candidates, { recentTracks: [], recentArtists: [], recentAlbums: [] }, 10, .3);
  assert.equal(result.filter((track) => track.artist === "PHARAOH").length, 2);
  assert.deepEqual(result.slice(0, 3).map((track) => track.artist), ["PHARAOH", "PHARAOH", "SALUKI"]);
});

test("rerank rejects tracks from the last 100 and albums from the last 5", () => {
  const repeated = item("repeat", "Artist", "Recent album", 1);
  const sameAlbum = item("new", "Other", "Recent album", .9);
  const allowed = item("ok", "Third", "Fresh album", .8);
  const result = rerank([repeated, sameAlbum, allowed], {
    recentTracks: ["artist::track repeat"],
    recentArtists: [],
    recentAlbums: ["recent album"]
  }, 3, .3);
  assert.deepEqual(result.map((track) => track.id), ["ok", "new"]);
});

test("discovery raises wild candidates without making ordering random", () => {
  const safe: WaveItem = { ...item("safe", "A", "A", .8), lane: "safe" };
  const wild: WaveItem = { ...item("wild", "B", "B", .78), lane: "wild" };
  assert.equal(rerank([safe, wild], { recentTracks: [], recentArtists: [], recentAlbums: [] }, 2, 0)[0]?.id, "safe");
  assert.equal(rerank([safe, wild], { recentTracks: [], recentArtists: [], recentAlbums: [] }, 2, 1)[0]?.id, "wild");
});

test("personalized artist weights influence ranking without bypassing repeat rules", () => {
  const preferred = item("preferred", "Loved Artist", "Fresh", .75);
  const generic = item("generic", "Other Artist", "Other", .8);
  const result = rerank([generic, preferred], {
    recentTracks: [],
    recentArtists: [],
    recentAlbums: [],
    personalization: {
      seedQueries: [],
      artistWeights: { "loved artist": 1 },
      discoveryDelta: 0,
      source: "agentrouter"
    }
  }, 2, .3);
  assert.equal(result[0]?.id, "preferred");
});

test("active Wave resumes from the current track and checkpoint", async () => {
  const gateway = {
    search: async () => Array.from({ length: 20 }, (_, index) => ({
      id: `track-${index}`,
      title: `Track ${index}`,
      artist: `Artist ${index}`,
      externalUrl: `https://soundcloud.com/test/track-${index}`
    }))
  } as unknown as ProviderGateway;
  const service = new WaveService(
    gateway,
    {} as YandexAdapter,
    undefined,
    () => 1_000
  );
  const started = await service.start({
    seedQueries: ["test"],
    enabledProviders: ["soundcloud"],
    discovery: .3,
    mood: "all",
    language: "any"
  }, {}, "owner");
  const current = started.items[5]!;
  await service.feedback(started.sessionId, {
    eventId: "82f6ea9f-5c50-4d3d-9bea-0d26ebad9bd2",
    type: "started",
    trackId: current.id,
    provider: current.provider,
    playedDurationMs: 0
  }, {}, "owner");
  service.checkpoint(started.sessionId, {
    provider: current.provider,
    trackId: current.id,
    positionMs: 42_000
  }, "owner");

  const active = service.active("owner");
  assert.equal(active?.items[0]?.id, current.id);
  assert.equal(active?.positionMs, 42_000);
  assert.equal(active?.currentTrackKey, `soundcloud:${current.id}`);
});
