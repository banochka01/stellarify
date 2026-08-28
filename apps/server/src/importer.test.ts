import assert from "node:assert/strict";
import test from "node:test";
import { parseImportPayload, parseImportLine } from "./importer.js";

test("detects Spotify playlists", () => {
  assert.deepEqual(
    parseImportLine("https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M"),
    {
      provider: "spotify",
      kind: "playlist",
      sourceUrl: "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M",
      externalId: "37i9dQZF1DXcBWIGoYBM5M",
      label: "Плейлист Spotify"
    }
  );
});

test("extracts YouTube list id and removes duplicates", () => {
  const url = "https://music.youtube.com/playlist?list=PL123";
  const result = parseImportPayload(`${url}\n${url}`);
  assert.equal(result.length, 1);
  assert.equal(result[0]?.provider, "youtube");
  assert.equal(result[0]?.externalId, "PL123");
});

test("keeps plain text as a search seed", () => {
  assert.deepEqual(parseImportLine("Tycho — Awake"), {
    provider: "unknown",
    kind: "text",
    label: "Tycho — Awake"
  });
});

