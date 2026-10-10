import assert from "node:assert/strict";
import test from "node:test";
import { WaveService, applyWaveContext, feedbackSignal, waveContext } from "./wave.js";
import type { ProviderGateway } from "./provider-gateway.js";
import type { YandexAdapter } from "./yandex.js";

test("wave context follows time of day and weekday only when mood is open", () => {
  assert.equal(waveContext(8, 2), "morning");
  assert.equal(waveContext(14, 3), "focus");
  assert.equal(waveContext(14, 6), "weekend");
  assert.equal(waveContext(20, 1), "evening");
  assert.equal(waveContext(2, 1), "night");
  assert.equal(waveContext(undefined, 1), undefined);
  const base = { seedQueries: [], enabledProviders: ["soundcloud" as const], discovery: .3, language: "any" as const };
  assert.equal(applyWaveContext({ ...base, mood: "all", localHour: 14, weekday: 2 }).request.mood, "calm");
  assert.equal(applyWaveContext({ ...base, mood: "sad", localHour: 14, weekday: 2 }).request.mood, "sad");
  assert.equal(feedbackSignal("skipped", 10_000), -1);
  assert.equal(feedbackSignal("skipped", 90_000), 0);
  assert.equal(feedbackSignal("finished", 200_000), 1);
});

test("radio seeds from the track, honours blocks and learns from early skips", async () => {
  const queries: string[] = [];
  let round = 0;
  const gateway = {
    search: async (_provider: string, query: string) => {
      queries.push(query);
      round += 1;
      return [
        ...Array.from({ length: 6 }, (_, index) => ({ id: `a${round}-${index}`, title: `A ${round} ${index}`, artist: "Skipped Artist", externalUrl: "https://soundcloud.com/a" })),
        ...Array.from({ length: 6 }, (_, index) => ({ id: `b${round}-${index}`, title: `B ${round} ${index}`, artist: `Fresh ${round} ${index}`, externalUrl: "https://soundcloud.com/b" })),
        { id: `x${round}`, title: "Blocked", artist: "Banned Artist", externalUrl: "https://soundcloud.com/x" }
      ];
    }
  } as unknown as ProviderGateway;
  const service = new WaveService(gateway, {} as YandexAdapter, undefined, () => 1_000);
  const started = await service.start({
    seedQueries: [],
    enabledProviders: ["soundcloud"],
    discovery: .3,
    mood: "all",
    language: "any",
    radioSeed: { title: "Song", artist: "Seed Artist" },
    blockedArtists: ["BANNED artist"]
  }, {}, "owner");
  assert.equal(queries[0], "Seed Artist");
  assert.equal(started.radio, true);
  assert.ok(started.items.every((entry) => entry.artist !== "Banned Artist"));
  const skipped = started.items.filter((entry) => entry.artist === "Skipped Artist");
  assert.ok(skipped.length > 0);
  for (let index = 0; index < 4; index += 1) {
    const entry = skipped[index % skipped.length]!;
    await service.feedback(started.sessionId, {
      eventId: `00000000-0000-4000-8000-00000000000${index}`,
      type: "skipped",
      trackId: entry.id,
      provider: entry.provider,
      playedDurationMs: 5_000
    }, {}, "owner");
  }
  const next = await service.next(started.sessionId, {}, "owner");
  assert.ok(next.items.length > 0);
  assert.ok(next.items.every((entry) => entry.artist !== "Skipped Artist"));
});
