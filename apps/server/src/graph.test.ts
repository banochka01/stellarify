import assert from "node:assert/strict";
import { test } from "node:test";
import { CallBudget } from "./api-helpers.js";
import { artistKey, coarse, createGraphRouter, MusicGraph, radioQueries } from "./graph.js";
import { headerAuth, serveRouter } from "./test-http.js";

const crowd = (sets: string[][], times: number) => Array.from({ length: times }, () => sets).flat();
const k = artistKey;

test("requests never build synchronously: first call kicks off a background rebuild", async () => {
  let reads = 0;
  const graph = new MusicGraph({ artistSets: () => { reads += 1; return crowd([["Alpha", "Bravo"]], 3); } });
  const first = await graph.neighbors("Alpha", { fallback: false });
  assert.deepEqual(first.neighbors, [], "old (empty) graph is served while rebuilding");
  await graph.rebuild();
  assert.equal(reads, 1, "concurrent rebuilds share one run");
  assert.ok(graph.builtAt > 0);
  assert.equal((await graph.neighbors("Alpha", { fallback: false })).neighbors[0]?.key, k("Bravo"));
});

test("rebuild yields to the event loop between chunks", async () => {
  const graph = new MusicGraph({ artistSets: () => crowd([["Alpha", "Bravo"]], 1_000) });
  let ticks = 0;
  const timer = setInterval(() => { ticks += 1; }, 0);
  await graph.rebuild();
  clearInterval(timer);
  assert.ok(ticks > 0, "timers ran during rebuild");
});

test("k-anonymity for co-listening and feat; hidden names; coarse weights", async () => {
  const sets = [
    ...crowd([["Alpha", "Bravo", "Gamma"]], 3),
    ["Alpha", "Secret"],            // one listener: must not leak
    ["Delta feat. Alpha"],          // one account's feat credit: hidden too
    ...crowd([["Echo feat. Alpha"]], 3)
  ];
  const graph = new MusicGraph({ artistSets: () => sets }, { minUsers: 3 });
  await graph.rebuild();
  const result = await graph.neighbors("Alpha", { fallback: false });
  const keys = result.neighbors.map((neighbor) => neighbor.key);
  assert.ok(keys.includes(k("Bravo")) && keys.includes(k("Gamma")) && keys.includes(k("Echo")));
  assert.ok(!keys.includes(k("Secret")));
  assert.ok(!keys.includes(k("Delta")));
  assert.deepEqual(result.neighbors.find((neighbor) => neighbor.key === k("Bravo"))?.kinds, { colisten: 2 }, "3 → coarse 2");
  assert.equal(result.neighbors.find((neighbor) => neighbor.key === k("Bravo"))?.artist, "Bravo");
  assert.equal(graph.displayName(k("Secret")), k("Secret"), "no original spelling for rare nodes");
  assert.deepEqual([coarse(0), coarse(1), coarse(3), coarse(9)], [0, 1, 2, 8]);
});

test("sparse nodes fall back to provider search within a call budget", async () => {
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
  await graph.rebuild();
  assert.deepEqual((await graph.neighbors("Newbie", { budget: new CallBudget(1) })).neighbors, [], "budget too small: no calls");
  assert.equal(searches, 0);
  const result = await graph.neighbors("Newbie", { budget: new CallBudget(4) });
  assert.equal(result.source, "providers");
  assert.deepEqual(result.neighbors.find((neighbor) => neighbor.key === k("Guest"))?.kinds, { feat: 1 });
  const before = searches;
  await graph.neighbors("Newbie", { budget: new CallBudget(0) });
  assert.equal(searches, before, "cached fallback costs nothing");
});

test("path from A to B walks the graph and yields radio queries", async () => {
  const sets = crowd([["Alpha", "Bravo"], ["Bravo", "Charlie"], ["Charlie", "Delta"]], 3);
  const graph = new MusicGraph({ artistSets: () => sets });
  await graph.rebuild();
  const path = await graph.path("Alpha", "Delta", { listened: new Set([k("Alpha")]) });
  assert.equal(path.found, true);
  assert.deepEqual(path.nodes.map((node) => node.artist), ["Alpha", "Bravo", "Charlie", "Delta"]);
  assert.equal(path.nodes[0]!.listened, true);
  const missing = await graph.path("Alpha", "Zulu");
  assert.equal(missing.found, false);
  assert.deepEqual(missing.nodes.map((node) => node.artist), ["Alpha", "Zulu"]);
  assert.deepEqual(radioQueries([{ artist: "X", via: [] }, { artist: "Y", via: ["feat"] }], 1).map((entry) => entry.query), ["X", "X Y", "Y"]);
});

test("graph routes: auth-only path with strict limit and call budget, personal layer", async () => {
  const sets = crowd([["Alpha", "Bravo"], ["Bravo", "Charlie"]], 3);
  let searches = 0;
  const graph = new MusicGraph({ artistSets: () => sets, search: async () => { searches += 1; return []; } });
  await graph.rebuild();
  const api = await serveRouter("/api/v1/graph", createGraphRouter(graph, {
    authenticate: headerAuth,
    taste: () => ({ listening: [], favorites: [{ title: "t", artist: "Alpha" }], playlistTracks: [] }),
    search: async (_provider, query) => {
      searches += 1;
      return [{ id: query, title: `${query} song`, artist: query, externalUrl: "https://e/x" }];
    }
  }));
  try {
    const neighbors = await api.call("GET", "/artist?name=Bravo", "u1");
    assert.equal(neighbors.body.neighbors.find((neighbor: { key: string }) => neighbor.key === k("Alpha")).listened, true);
    assert.equal((await api.call("GET", "/path?from=Alpha&to=Charlie")).status, 401);
    searches = 0;
    const path = await api.call("GET", "/path?from=Alpha&to=Zulu&tracks=1", "u1");
    assert.equal(path.status, 200);
    assert.ok(searches <= 20, `budget respected: ${searches}`);
    for (let index = 0; index < 5; index += 1) await api.call("GET", "/path?from=Alpha&to=Charlie", "u1");
    assert.equal((await api.call("GET", "/path?from=Alpha&to=Charlie", "u1")).status, 429);
    const me = await api.call("GET", "/me", "u2");
    assert.equal(me.body.listened[0].artist, "Alpha");
    assert.ok(me.body.unexplored.some((entry: { key: string }) => entry.key === k("Bravo")));
  } finally {
    await api.close();
  }
});
