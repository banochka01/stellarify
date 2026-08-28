import assert from "node:assert/strict";
import test from "node:test";
import { SoundCloudAudioRelay } from "./soundcloud-audio-relay.js";

const ticket = "abcdefghijklmnopqrstuvwxyz123456";
const proxyUrl = "203.0.113.8:8080:user:pass";

test("relays a progressive SoundCloud stream through the configured proxy", async () => {
  const calls: Array<{ url: string; init?: RequestInit & { dispatcher?: unknown } }> = [];
  const relay = new SoundCloudAudioRelay(
    proxyUrl,
    async (input, init) => {
      calls.push({ url: String(input), init });
      return new Response("audio", {
        status: 206,
        headers: {
          "content-type": "audio/mpeg",
          "content-range": "bytes 0-4/100"
        }
      });
    },
    () => 1_000,
    () => ticket
  );
  const issued = relay.issue({
    streamUrl: "https://cf-media.sndcdn.com/track.mp3",
    protocol: "progressive"
  });

  const response = await relay.open(ticket, "GET", { range: "bytes=0-4" });

  assert.equal(
    issued.streamUrl,
    `/api/v1/playback/soundcloud-relay/${ticket}`
  );
  assert.equal(issued.expiresAt, "1970-01-01T00:30:01.000Z");
  assert.equal(response.status, 206);
  assert.equal(calls[0]?.url, "https://cf-media.sndcdn.com/track.mp3");
  assert.equal(new Headers(calls[0]?.init?.headers).get("range"), "bytes=0-4");
  assert.ok(calls[0]?.init?.dispatcher);
  assert.equal(calls[0]?.init?.redirect, "manual");
});

test("rejects relay tickets for HLS and missing proxy configuration", () => {
  const hlsRelay = new SoundCloudAudioRelay(
    proxyUrl,
    async () => new Response(),
    () => 1_000,
    () => ticket
  );
  assert.throws(
    () =>
      hlsRelay.issue({
        streamUrl: "https://cf-hls-media.sndcdn.com/track.m3u8",
        protocol: "hls"
      }),
    /requires a progressive stream/
  );

  const unavailable = new SoundCloudAudioRelay(undefined);
  assert.throws(
    () =>
      unavailable.issue({
        streamUrl: "https://cf-media.sndcdn.com/track.mp3",
        protocol: "progressive"
      }),
    /not configured/
  );
});

test("rejects redirects outside SoundCloud CDN domains", async () => {
  const relay = new SoundCloudAudioRelay(
    proxyUrl,
    async () =>
      new Response(null, {
        status: 302,
        headers: { location: "https://attacker.example/audio.mp3" }
      }),
    () => 1_000,
    () => ticket
  );
  relay.issue({
    streamUrl: "https://cf-media.sndcdn.com/track.mp3",
    protocol: "progressive"
  });

  await assert.rejects(
    () => relay.open(ticket, "GET", {}),
    /unexpected stream host/
  );
});
