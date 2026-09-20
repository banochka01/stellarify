import assert from "node:assert/strict";
import test from "node:test";
import { ArtworkRelay, rewriteArtworkUrls } from "./artwork-relay.js";

test("artwork relay wraps supported provider covers and fetches the decoded URL", async () => {
  let requested = "";
  const relay = new ArtworkRelay(async (input) => {
    requested = String(input);
    return new Response(Uint8Array.from([1, 2, 3]), {
      headers: { "content-type": "image/jpeg" }
    });
  });
  const rewritten = rewriteArtworkUrls(
    { provider: "spotify", artworkUrl: "https://i.scdn.co/image/test", nested: [{ artworkUrl: "https://i1.sndcdn.com/art.jpg" }] },
    relay,
    (path) => `https://music.example${path}`
  ) as Record<string, any>;

  assert.match(rewritten.artworkUrl, /^https:\/\/music\.example\/api\/v1\/media\/artwork\//);
  assert.match(rewritten.nested[0].artworkUrl, /^https:\/\/music\.example\/api\/v1\/media\/artwork\//);
  const ticket = new URL(rewritten.artworkUrl).pathname.split("/").at(-1)!;
  const response = await relay.open(ticket, "GET", {});
  assert.equal(response.status, 200);
  assert.equal(requested, "https://i.scdn.co/image/test");
});

test("artwork relay leaves unrelated URLs alone and rejects forged hosts", async () => {
  const relay = new ArtworkRelay(fetch);
  const rewritten = rewriteArtworkUrls(
    { artworkUrl: "https://private.example/cover.jpg" },
    relay,
    (path) => `https://music.example${path}`
  ) as Record<string, unknown>;
  assert.equal(rewritten.artworkUrl, "https://private.example/cover.jpg");

  const forged = Buffer.from("https://127.0.0.1/secret", "utf8").toString("base64url");
  await assert.rejects(() => relay.open(forged, "GET", {}), /Artwork relay URL is invalid/);
});
