import assert from "node:assert/strict";
import test from "node:test";
import { ReleaseService, lastFriday, releaseTime } from "./releases.js";

const DAY = 24 * 60 * 60_000;

test("lastFriday and release date precision", () => {
  assert.equal(new Date(lastFriday(Date.parse("2026-10-11T12:00:00Z"))).toISOString(), "2026-10-09T00:00:00.000Z");
  assert.equal(new Date(lastFriday(Date.parse("2026-10-09T01:00:00Z"))).toISOString(), "2026-10-09T00:00:00.000Z");
  assert.equal(releaseTime("2026"), Date.parse("2026-01-01T00:00:00Z"));
});

test("release feed caches catalogs, filters by date and builds the fresh week", async () => {
  const now = Date.parse("2026-10-11T12:00:00Z");
  let sourceCalls = 0;
  const source = {
    configured: true,
    artistReleases: async (artist: string) => {
      sourceCalls += 1;
      return [
        { id: `${artist}-new`, title: "New Single", artist, releaseDate: "2026-10-09", kind: "single" as const, externalUrl: "https://open.spotify.com/album/1" },
        { id: `${artist}-old`, title: "Old Album", artist, releaseDate: "2020-01-01", kind: "album" as const, externalUrl: "https://open.spotify.com/album/2" },
        { id: `${artist}-other`, title: "Unrelated", artist: "Somebody Else", releaseDate: "2026-10-10", kind: "album" as const, externalUrl: "https://open.spotify.com/album/3" }
      ];
    }
  };
  const service = new ReleaseService(source, async (provider, query) => [
    { id: `${provider}-${query}`, title: "New Single", artist: query.split(" ")[0]!, externalUrl: "https://soundcloud.com/x" }
  ], {}, () => now);
  const feed = await service.feed(["Alpha", "alpha", "Beta"]);
  assert.equal(sourceCalls, 2);
  assert.deepEqual(feed.releases.map((release) => release.id).sort(), ["Alpha-new", "Beta-new"]);
  await service.feed(["Alpha"]);
  assert.equal(sourceCalls, 2);
  assert.equal(await service.poll(), 0);
  const week = await service.freshWeek(["Alpha", "Beta"], ["soundcloud", "spotify"]);
  assert.equal(week.weekOf, "2026-10-09");
  assert.equal(week.tracks.length, 2);
  assert.ok(week.tracks.every((track) => track.provider === "soundcloud"));
  assert.equal(Date.parse(week.nextRefreshAt) - Date.parse("2026-10-09T00:00:00Z"), 7 * DAY);
});

test("unconfigured catalog reports unavailable without calling the source", async () => {
  const service = new ReleaseService({ configured: false, artistReleases: async () => { throw new Error("no"); } }, async () => []);
  assert.deepEqual(await service.feed(["A"]), { available: false, releases: [] });
});
