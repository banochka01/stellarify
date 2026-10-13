import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { AccountStore } from "./account-store.js";

test("graph artist sets are windowed and capped; friends history is one grouped query", async () => {
  const directory = mkdtempSync(join(tmpdir(), "resonance-social-"));
  const store = new AccountStore(join(directory, "a.sqlite"), "pepper");
  try {
    const a = (await store.register("a@example.com", "long password 1", "t")).user.id;
    const b = (await store.register("b@example.com", "long password 2", "t")).user.id;
    const play = (user: string, artist: string, title: string, type: "finished" | "skipped" = "finished") =>
      store.recordWaveFeedback(user, { eventId: randomUUID(), type, provider: "soundcloud", trackId: `${artist}-${title}`, playedDurationMs: 1 }, { title, artist });
    play(a, "Muse", "Uprising");
    play(a, "Muse", "Uprising");
    play(a, "Radiohead", "Creep");
    play(a, "Skipped", "Nope", "skipped");
    play(b, "Muse", "Starlight");

    const sets = store.listeningArtistSets();
    assert.equal(sets.length, 2);
    assert.ok(sets.every((set) => !set.includes("Skipped")));
    assert.deepEqual(store.listeningArtistSets(5_000, 60, -1), [], "rows outside the window are excluded");
    assert.equal(store.listeningArtistSets(5_000, 60, 90, 1).flat().length, 1, "row LIMIT applies before loading");

    const recent = store.recentListening([a, b], 0, 5);
    assert.deepEqual(recent.get(a)?.map((item) => item.title).sort(), ["Creep", "Uprising"], "deduplicated, no skips");
    assert.equal(recent.get(b)?.[0]?.title, "Starlight");
    assert.equal(store.recentListening([], 0).size, 0);
  } finally {
    store.close();
    rmSync(directory, { recursive: true, force: true });
  }
});
