import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { AccountStore } from "./account-store.js";

test("year stats count real plays, dedupe events and survive wave profile reset", async () => {
  const directory = mkdtempSync(join(tmpdir(), "resonance-year-"));
  const store = new AccountStore(join(directory, "a.sqlite"), "pepper");
  try {
    const user = (await store.register("y@example.com", "long password 1", "t")).user.id;
    const send = (eventId: string, type: "finished" | "skipped" | "liked", ms: number, artist = "Muse", title = "Uprising") =>
      store.recordWaveFeedback(user, { eventId, type, provider: "soundcloud", trackId: title, playedDurationMs: ms }, { title, artist, album: "The Resistance" });
    send("e1", "finished", 300_000);
    send("e1", "finished", 300_000);
    send("e2", "finished", 240_000);
    send("e3", "skipped", 5_000, "Radiohead", "Creep");
    send("e4", "skipped", 60_000, "Radiohead", "Creep");
    send("e5", "liked", 0);
    store.clearWaveFeedback(user);

    const stats = store.yearStats(user, new Date().getUTCFullYear());
    assert.equal(stats.plays, 3, "short skips and likes are not plays; duplicate event ignored");
    assert.equal(stats.minutes, 10);
    assert.deepEqual(stats.artists.map((item) => [item.label, item.plays]), [["Muse", 2], ["Radiohead", 1]]);
    assert.equal(stats.tracks[0]?.label, "Muse — Uprising");
    assert.equal(stats.albums[0]?.label, "Muse — The Resistance");
    assert.equal(stats.months.length, 1);
    assert.equal(store.yearStats(user, 1999).plays, 0);
  } finally {
    store.close();
    rmSync(directory, { recursive: true, force: true });
  }
});
