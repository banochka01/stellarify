import assert from "node:assert/strict";
import test from "node:test";
import { rerank, type WaveItem } from "./wave.js";

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
