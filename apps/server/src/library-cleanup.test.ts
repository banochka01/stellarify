import assert from "node:assert/strict";
import { test } from "node:test";
import { collectLibraryItems, createLibraryCleanupRouter, findDuplicates, LibraryCleanupService } from "./library-cleanup.js";
import { headerAuth, serveRouter } from "./test-http.js";

const track = (id: string, title: string, artist: string, provider?: string, duration?: number) => ({
  id, title, artist, duration,
  sources: provider ? [{ provider, externalId: id, externalUrl: `https://example.com/${id}`, metadata: {} }] : []
});

const library = {
  favorites: [
    track("y1", "Группа крови", "Кино", "yandex", 283_000),
    track("s1", "Gruppa Krovi (Remastered 2019)", "Kino", "soundcloud", 284_000),
    track("v1", "Something Else", "Other", "vk"),
    track("n1", "Ghost Track", "Nobody")
  ],
  playlists: [{ id: "p1", name: "Дорога", tracks: [{ position: 0, track: track("y1", "Группа крови", "Кино", "yandex", 283_000) }] }]
};

test("duplicates across providers are grouped with a suggested keeper", () => {
  const items = collectLibraryItems(library);
  assert.equal(items.length, 4);
  assert.equal(items.find((item) => item.trackId === "y1")!.locations.length, 2);
  const groups = findDuplicates(items, ["soundcloud", "yandex"]);
  assert.equal(groups.length, 1);
  assert.equal(groups[0]!.crossProvider, true);
  // Priority list puts SoundCloud first.
  assert.equal(groups[0]!.keep.trackId, "s1");
  assert.deepEqual(groups[0]!.duplicates.map((item) => item.trackId), ["y1"]);
});

test("cleanup route suggests replacements for unavailable tracks", async () => {
  const service = new LibraryCleanupService(() => library, async (provider, query) => provider === "soundcloud" && /ghost/i.test(query)
    ? [{ id: "sc-ghost", title: "Ghost Track", artist: "Nobody", externalUrl: "https://soundcloud.com/x" }]
    : []);
  const api = await serveRouter("/api/v1/library/cleanup", createLibraryCleanupRouter(service, headerAuth));
  try {
    assert.equal((await api.call("POST", "/", undefined, {})).status, 401);
    const result = await api.call("POST", "/", "u1", { enabledProviders: ["soundcloud", "yandex"], unavailableTrackIds: [] });
    assert.equal(result.status, 200);
    assert.equal(result.body.scanned, 4);
    assert.equal(result.body.duplicates.length, 1);
    const reasons = Object.fromEntries(result.body.replacements.map((entry: { item: { trackId: string }; reason: string }) => [entry.item.trackId, entry.reason]));
    assert.deepEqual(reasons, { v1: "provider_disabled", n1: "no_sources" });
    const ghost = result.body.replacements.find((entry: { item: { trackId: string } }) => entry.item.trackId === "n1");
    assert.equal(ghost.suggestion.id, "sc-ghost");
    assert.equal(ghost.suggestion.provider, "soundcloud");
    assert.equal((await api.call("POST", "/", "u1", { enabledProviders: ["nope"] })).status, 400);
  } finally {
    await api.close();
  }
});
