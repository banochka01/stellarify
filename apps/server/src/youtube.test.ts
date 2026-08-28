import assert from "node:assert/strict";
import test from "node:test";
import { YouTubeAdapter } from "./youtube.js";

const key = "A".repeat(32);

test("imports every YouTube playlist page as official links", async () => {
  const calls: URL[] = [];
  const adapter = new YouTubeAdapter(undefined, async (input) => {
    const url = new URL(input.toString());
    calls.push(url);
    if (url.pathname.endsWith("/playlists")) {
      return Response.json({ items: [{ snippet: { title: "Night Drive", thumbnails: { high: { url: "https://img.example/playlist.jpg" } } } }] });
    }
    const second = url.searchParams.get("pageToken") === "next";
    return Response.json({
      items: [{ contentDetails: { videoId: second ? "video-2" : "video-1" }, snippet: { title: second ? "Two" : "One", videoOwnerChannelTitle: "Artist", thumbnails: { medium: { url: "https://img.example/track.jpg" } } } }],
      ...(second ? {} : { nextPageToken: "next" })
    });
  });

  const playlist = await adapter.importPlaylist("PL12345678", { token: key });
  assert.equal(playlist.title, "Night Drive");
  assert.deepEqual(playlist.tracks.map((track) => track.id), ["video-1", "video-2"]);
  assert.equal(playlist.tracks[0]?.externalUrl, "https://www.youtube.com/watch?v=video-1");
  assert.equal(calls.length, 3);
  assert(calls.every((url) => url.searchParams.get("key") === key));
});

test("rejects YouTube requests without an API key", async () => {
  const adapter = new YouTubeAdapter();
  await assert.rejects(() => adapter.searchTracks("track", 5), /API key/u);
});

test("validates a user key while preserving the server key fallback", async () => {
  const keys: string[] = [];
  const adapter = new YouTubeAdapter("S".repeat(32), async (input) => {
    keys.push(new URL(input.toString()).searchParams.get("key") ?? "");
    return Response.json({ items: [{ id: "dQw4w9WgXcQ" }] });
  });

  assert.equal(adapter.serverCredentialConfigured, true);
  await adapter.validateAccess();
  await adapter.validateAccess({ token: "U".repeat(32) });

  assert.deepEqual(keys, ["S".repeat(32), "U".repeat(32)]);
});
