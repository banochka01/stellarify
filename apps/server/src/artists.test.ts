import assert from "node:assert/strict";
import { test } from "node:test";
import { openSqlite } from "./api-helpers.js";
import { ArtistPageService, BandsintownConcerts, createArtistRouter } from "./artists.js";
import type { Release } from "./releases.js";
import { SocialStore } from "./social-store.js";
import { headerAuth, serveRouter } from "./test-http.js";

const day = (offset: number) => new Date(Date.now() + offset * 86_400_000).toISOString().slice(0, 10);

test("artist overview aggregates tracks, releases, clips and degrades without keys; follows feed unread releases", async () => {
  const social = new SocialStore(openSqlite(":memory:"));
  let releases: Release[] = [
    { id: "r-old", provider: "spotify", title: "Old", artist: "Muse", releaseDate: day(-30), kind: "album", externalUrl: "https://open.spotify.com/album/1" },
    { id: "r-new", provider: "spotify", title: "New", artist: "Muse", releaseDate: day(0), kind: "single", externalUrl: "https://open.spotify.com/album/2" }
  ];
  const service = new ArtistPageService({
    search: async (_provider, query) => [
      { id: "t1", title: "Uprising", artist: query, externalUrl: "https://e/1" },
      { id: "t2", title: "Cover", artist: "Someone Else", externalUrl: "https://e/2" }
    ],
    releases: { available: true, feed: async () => ({ available: true, releases }) },
    clips: { find: async (title) => title === "Uprising" ? [{ id: "clip1" } as never] : [] },
    concerts: new BandsintownConcerts(""),
    social
  });
  const api = await serveRouter("/api/v1/artists", createArtistRouter(service, social, headerAuth));
  try {
    const overview = await api.call("GET", "/overview?name=Muse", "u1");
    assert.equal(overview.status, 200);
    assert.deepEqual(overview.body.topTracks.map((track: { id: string }) => track.id), ["t1"]);
    assert.equal(overview.body.releases.items.length, 2);
    assert.equal(overview.body.clips.length, 1);
    assert.deepEqual(overview.body.concerts, { available: false, items: [] });
    assert.deepEqual(overview.body.setlists, { available: false, setlists: [] });
    assert.equal(overview.body.following, false);

    assert.equal((await api.call("PUT", "/follows", undefined, { artist: "Muse" })).status, 401);
    assert.equal((await api.call("PUT", "/follows", "u1", { artist: "Muse" })).status, 200);
    assert.equal((await api.call("GET", "/overview?name=Muse", "u1")).body.following, true);
    const unread = await api.call("GET", "/releases/unread", "u1");
    assert.equal(unread.body.count, 1, "only releases since the follow day");
    assert.equal(unread.body.releases[0].id, "r-new");
    assert.equal((await api.call("POST", "/releases/seen", "u1", {})).body.marked, 1);
    assert.equal((await api.call("GET", "/releases/unread", "u1")).body.count, 0);
    releases = [...releases, { id: "r-newer", provider: "spotify", title: "Newer", artist: "Muse", releaseDate: day(0), kind: "single", externalUrl: "https://open.spotify.com/album/3" }];
    assert.equal((await api.call("GET", "/releases/unread", "u1")).body.count, 1);
    assert.equal((await api.call("POST", "/releases/seen", "u1", { artist: "Queen" })).status, 404);
    assert.equal((await api.call("DELETE", "/follows?artist=Muse", "u1")).status, 204);
    assert.deepEqual((await api.call("GET", "/follows", "u1")).body.follows, []);
  } finally {
    await api.close();
  }
});

test("bandsintown concerts are parsed when configured", async () => {
  const concerts = new BandsintownConcerts("app", (async (url: URL) => {
    assert.match(String(url), /artists\/Muse\/events\?app_id=app/);
    return new Response(JSON.stringify([{ id: 7, datetime: "2026-11-01T19:00:00", url: "https://www.bandsintown.com/e/7", venue: { name: "Arena", city: "Berlin", country: "Germany" } }]));
  }) as typeof fetch);
  assert.deepEqual(await concerts.upcoming("Muse"), [{ id: "7", date: "2026-11-01T19:00:00", venue: "Arena", city: "Berlin", country: "Germany", url: "https://www.bandsintown.com/e/7" }]);
});
