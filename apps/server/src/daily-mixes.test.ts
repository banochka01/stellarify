import assert from "node:assert/strict";
import test from "node:test";
import { DailyMixService, mixWindow } from "./daily-mixes.js";

const search = async (_provider: string, query: string, limit: number) => Array.from({ length: limit }, (_, index) => ({
  id: `${query}-${index}`,
  title: `${query} track ${index}`,
  artist: query.endsWith(" feat") ? `Guest ${query} ${index}` : query.split(" ")[0]!,
  externalUrl: `https://soundcloud.com/${index}`
}));

test("mix day starts at 06:00 local time", () => {
  const moscow = 180;
  const before = mixWindow(Date.parse("2026-10-11T02:59:00Z"), moscow);
  const after = mixWindow(Date.parse("2026-10-11T03:01:00Z"), moscow);
  assert.equal(before.day, "2026-10-10");
  assert.equal(after.day, "2026-10-11");
  assert.equal(new Date(after.start).toISOString(), "2026-10-11T03:00:00.000Z");
});

test("daily mixes come from favorites, related artists and forgotten tracks, cached for the day", async () => {
  let calls = 0;
  let now = Date.parse("2026-10-11T08:00:00Z");
  const service = new DailyMixService(async (provider, query, limit) => {
    calls += 1;
    return search(provider, query, limit);
  }, () => now);
  const input = {
    favoriteArtists: ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta"],
    forgottenTracks: [{ title: "Old", artist: "Alpha" }],
    blockedArtists: [],
    blockedTracks: [],
    enabledProviders: ["soundcloud" as const],
    tzOffsetMinutes: 180
  };
  const result = await service.build("user", input);
  assert.deepEqual(result.mixes.map((mix) => mix.title), ["Утро", "Фокус", "Вечер", "Открытия"]);
  const discovery = result.mixes.find((mix) => mix.kind === "discovery")!;
  assert.ok(discovery.tracks.every((track) => track.artist.startsWith("Guest")));
  const firstCalls = calls;
  now += 60 * 60_000;
  assert.deepEqual(await service.build("user", input), result);
  assert.equal(calls, firstCalls);
  now += 24 * 60 * 60_000;
  await service.build("user", input);
  assert.ok(calls > firstCalls);
});

test("blocked artists never appear in mixes", async () => {
  const service = new DailyMixService(search, () => Date.parse("2026-10-11T08:00:00Z"));
  const result = await service.build("user", {
    favoriteArtists: ["Alpha", "Beta", "Gamma"],
    forgottenTracks: [],
    blockedArtists: ["alpha"],
    blockedTracks: [],
    enabledProviders: ["soundcloud"],
    tzOffsetMinutes: 0
  });
  assert.ok(result.mixes.flatMap((mix) => mix.tracks).every((track) => track.artist !== "Alpha"));
});
