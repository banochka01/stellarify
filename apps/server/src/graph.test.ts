import assert from "node:assert/strict";
import { test } from "node:test";
import { artistKey, createGraphRouter, MusicGraph, radioQueries } from "./graph.js";
import { headerAuth, serveRouter } from "./test-http.js";

const crowd = (sets: string[][], times: number) => Array.from({ length: times }, () => sets).flat();
const k = artistKey;

test("co-listening edges need k-anonymity; feat credits always link", async () => {
  const sets = [
    ...crowd([["Alpha", "Bravo", "Gamma"]], 3),
    ["Alpha", "Secret"], // a single listener: must not leak into the graph
    ["Delta feat. Alpha"]
  ];
  const graph = new MusicGraph({ artistSets: () => sets }, { minUsers: 3 });
  const result = await graph.neighbors("Alpha", { fallback: false });
  const keys = result.neighbors.map((neighbor) => neighbor.key);
  assert.ok(keys.includes(k("Bravo")));
  assert.ok(keys.includes(k("Gamma")));
  assert.ok(keys.includes(k("Delta")));
  assert.ok(!keys.includes(k("Secret")));
  assert.deepEqual(result.neighbors.find((neighbor) => neighbor.key === k("Bravo"))?.kinds, { colisten: 3 });
  assert.equal(result.neighbors.find((neighbor) => neighbor.key === k("Bravo"))?.artist, "Bravo");
  assert.deepEqual(result.neighbors.find((neighbor) => neighbor.key === k("Delta"))?.kinds, { feat: 1 });
});

test("sparse nodes fall back to provider search (feat + similar)", async () => {
  let searches = 0;
  const graph = new MusicGraph({
    artistSets: () => [],
    search: async (_provider, query) => {
      searches += 1;
      return query.endsWith("feat")
        ? [{ id: "1", title: "x", artist: "Newbie feat. Guest", externalUrl: "https://e/1" }]
        : [{ id: "2", title: "y", artist: "Somebody Else", externalUrl: "https://e/2" }];
    },
    fallbackProviders: ["soundcloud"]
  });
  const result = await graph.neighbors("Newbie");
  assert.equal(result.source, "providers");
  assert.deepEqual(result.neighbors.find((neighbor) => neighbor.key === k("Guest"))?.kinds, { feat: 1 });
  assert.deepEqual(result.neighbors.find((neighbor) => neighbor.key === k("Somebody Else"))?.kinds, { similar: 1 });
  const before = searches;
  await graph.neighbors("Newbie");
  assert.equal(searches, before, "fallback is cached");
});

test("path from A to B walks the graph and yields radio queries", async () => {
  const sets = crowd([["Alpha", "Bravo"], ["Bravo", "Charlie"], ["Charlie", "Delta"]], 3);
  const graph = new MusicGraph({ artistSets: () => sets });
  const path = await graph.path("Alpha", "Delta", { listened: new Set([k("Alpha")]) });
  assert.equal(path.found, true);
  assert.deepEqual(path.nodes.map((node) => node.artist), ["Alpha", "Bravo", "Charlie", "Delta"]);
  assert.equal(path.nodes[0]!.listened, true);
  assert.equal(path.nodes[3]!.listened, false);
  assert.ok(path.queries.length >= 4);
  const missing = await graph.path("Alpha", "Zulu");
  assert.equal(missing.found, false);
  assert.deepEqual(missing.nodes.map((node) => node.artist), ["Alpha", "Zulu"]);
  assert.deepEqual(radioQueries([{ artist: "X", via: [] }, { artist: "Y", via: ["feat"] }], 1).map((entry) => entry.query), ["X", "X Y", "Y"]);
});

test("graph routes: neighbours, path with tracks and personal layer", async () => {
  const sets = crowd([["Alpha", "Bravo"], ["Bravo", "Charlie"]], 3);
  const graph = new MusicGraph({ artistSets: () => sets });
  const api = await serveRouter("/api/v1/graph", createGraphRouter(graph, {
    authenticate: headerAuth,
    taste: () => ({ listening: [], favorites: [{ title: "t", artist: "Alpha" }], playlistTracks: [] }),
    search: async (_provider, query) => [{ id: query, title: `${query} song`, artist: query, externalUrl: "https://e/x" }]
  }));
  try {
    const neighbors = await api.call("GET", "/artist?name=Bravo", "u1");
    assert.equal(neighbors.status, 200);
    assert.equal(neighbors.body.neighbors.find((neighbor: { key: string }) => neighbor.key === k("Alpha")).listened, true);
    assert.equal((await api.call("GET", "/artist")).status, 400);
    const path = await api.call("GET", "/path?from=Alpha&to=Charlie&tracks=1");
    assert.equal(path.body.found, true);
    assert.ok(path.body.tracks.length >= 3);
    assert.match(path.body.tracks[0].reason, /По пути/);
    assert.equal((await api.call("GET", "/me")).status, 401);
    const me = await api.call("GET", "/me", "u1");
    assert.equal(me.body.listened[0].artist, "Alpha");
    assert.ok(me.body.unexplored.some((entry: { key: string }) => entry.key === k("Bravo")));
  } finally {
    await api.close();
  }
});
