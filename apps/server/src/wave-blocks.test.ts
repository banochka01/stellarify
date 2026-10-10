import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { AccountStore } from "./account-store.js";

test("wave blocks merge by last write with tombstones", async () => {
  const directory = mkdtempSync(join(tmpdir(), "resonance-blocks-"));
  const store = new AccountStore(join(directory, "account.sqlite"), "pepper");
  try {
    const session = await store.register("blocks@example.com", "long-password-1", "test");
    const userId = session.user.id;
    store.mergeWaveBlocks(userId, [
      { kind: "artist", key: "artist a", label: "Artist A", removed: false, updatedAt: "2026-01-02T00:00:00.000Z" }
    ]);
    // An older tombstone from another device must not resurrect/undo the newer state.
    store.mergeWaveBlocks(userId, [
      { kind: "artist", key: "artist a", label: "Artist A", removed: true, updatedAt: "2026-01-01T00:00:00.000Z" }
    ]);
    assert.equal(store.getWaveBlocks(userId)[0]?.removed, false);
    const merged = store.mergeWaveBlocks(userId, [
      { kind: "artist", key: "artist a", label: "Artist A", removed: true, updatedAt: "2026-01-03T00:00:00.000Z" },
      { kind: "track", key: "b::song", label: "B — Song", removed: false, updatedAt: "2026-01-03T00:00:00.000Z" }
    ]);
    assert.equal(merged.length, 2);
    assert.equal(merged.find((block) => block.kind === "artist")?.removed, true);
  } finally {
    store.close();
    rmSync(directory, { recursive: true, force: true });
  }
});
