import assert from "node:assert/strict";
import test from "node:test";
import {
  normalizeProxyUrl,
  SoundCloudAdapter
} from "./soundcloud.js";

const clientId = "abcdefghijklmnopqrstuvwxyz123456";

function jsonResponse(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "content-type": "application/json" }
  });
}

function publicTrack() {
  return {
    urn: "soundcloud:tracks:42",
    id: 42,
    title: "Awake",
    duration: 123000,
    artwork_url: "https://i1.sndcdn.com/artwork-large.jpg",
    permalink_url: "https://soundcloud.com/tycho/awake",
    track_authorization: "track-auth",
    user: { username: "Tycho" },
    media: {
      transcodings: [
        {
          url: "https://api-v2.soundcloud.com/media/soundcloud:tracks:42/stream/encrypted",
          preset: "opus_0_0",
          format: {
            protocol: "ctr-encrypted-hls",
            mime_type: "audio/ogg; codecs=opus"
          }
        },
        {
          url: "https://api-v2.soundcloud.com/media/soundcloud:tracks:42/stream/hls",
          preset: "aac_0_1",
          quality: "sq",
          format: {
            protocol: "hls",
            mime_type: 'audio/mp4; codecs="mp4a.40.2"'
          }
        },
        {
          url: "https://api-v2.soundcloud.com/media/soundcloud:tracks:42/stream/progressive",
          preset: "mp3_0_1",
          quality: "sq",
          format: { protocol: "progressive", mime_type: "audio/mpeg" }
        }
      ]
    }
  };
}

test("uses a server Client ID for public API v2 search", async () => {
  const calls: URL[] = [];
  const adapter = new SoundCloudAdapter(
    { clientId },
    async (input) => {
      const url = new URL(String(input));
      calls.push(url);
      return jsonResponse({ collection: [publicTrack()] });
    }
  );

  const tracks = await adapter.searchTracks("Tycho", 10);

  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.hostname, "api-v2.soundcloud.com");
  assert.equal(calls[0]?.searchParams.get("client_id"), clientId);
  assert.deepEqual(tracks, [
    {
      id: "soundcloud:tracks:42",
      title: "Awake",
      artist: "Tycho",
      durationMs: 123000,
      artworkUrl: "https://i1.sndcdn.com/artwork-t500x500.jpg",
      externalUrl: "https://soundcloud.com/tycho/awake"
    }
  ]);
  assert.equal(calls.length, 1);
});

test("accepts a user Client ID like the Yandex credential field", async () => {
  const calls: URL[] = [];
  const adapter = new SoundCloudAdapter({}, async (input) => {
    calls.push(new URL(String(input)));
    return jsonResponse({ collection: [] });
  });

  await adapter.searchTracks("Tycho", 10, {
    token: clientId,
    cacheScope: "user-a"
  });

  assert.equal(calls[0]?.searchParams.get("client_id"), clientId);
});

test("keeps support for a real OAuth API access token", async () => {
  const authorizations: Array<string | null> = [];
  const adapter = new SoundCloudAdapter({}, async (_input, init) => {
    authorizations.push(
      new Headers(init?.headers).get("authorization")
    );
    return jsonResponse({ collection: [] });
  });

  await adapter.searchTracks("Tycho", 10, {
    token: "OAuth real-api-access-token"
  });

  assert.deepEqual(authorizations, ["OAuth real-api-access-token"]);
});

test("falls back to the server Client ID for a stale browser cookie", async () => {
  const requested: URL[] = [];
  const adapter = new SoundCloudAdapter({ clientId }, async (input) => {
    requested.push(new URL(String(input)));
    return jsonResponse({ collection: [] });
  });

  await adapter.searchTracks("Tycho", 10, {
    token: "2-329470-1718068196-example"
  });

  assert.equal(requested[0]?.searchParams.get("client_id"), clientId);
  assert.equal(requested.length, 1);
});

test("still rejects a browser cookie during explicit validation", async () => {
  const adapter = new SoundCloudAdapter({ clientId }, async () =>
    jsonResponse({})
  );
  await assert.rejects(
    () => adapter.validateAccess({ token: "2-329470-1718068196-example" }),
    /cookie is not an API credential/
  );
});

test("prefers native-compatible progressive MP3 over fragmented MP4 HLS", async () => {
  const calls: URL[] = [];
  const adapter = new SoundCloudAdapter(
    { clientId },
    async (input) => {
      const url = new URL(String(input));
      calls.push(url);
      if (url.pathname.startsWith("/tracks/")) {
        return jsonResponse(publicTrack());
      }
      return jsonResponse({
        url: "https://playback.media-streaming.soundcloud.cloud/audio.m3u8?Expires=2000000000"
      });
    }
  );

  const source = await adapter.resolve("soundcloud:tracks:42", "high");

  assert.equal(source.protocol, "progressive");
  assert.equal(source.codec, "mp3");
  assert.equal(
    calls[1]?.searchParams.get("track_authorization"),
    "track-auth"
  );
  assert.equal(calls[1]?.searchParams.get("client_id"), clientId);
});

test("uses progressive MP3 when AAC HLS is unavailable", async () => {
  const track = publicTrack();
  track.media.transcodings.splice(0, 2);
  const adapter = new SoundCloudAdapter(
    { clientId },
    async (input) =>
      new URL(String(input)).pathname.startsWith("/tracks/")
        ? jsonResponse(track)
        : jsonResponse({
            url: "https://cf-media.sndcdn.com/audio.mp3?Expires=2000000000"
          })
  );

  const source = await adapter.resolve("42", "high");

  assert.equal(source.protocol, "progressive");
  assert.equal(source.codec, "mp3");
});

test("uses progressive MP3 for low quality when audio relay is enabled", async () => {
  const calls: URL[] = [];
  const adapter = new SoundCloudAdapter(
    {
      clientId,
      proxyUrl: "203.0.113.8:8080:user:pass"
    },
    async (input) => {
      const url = new URL(String(input));
      calls.push(url);
      return url.pathname.startsWith("/tracks/")
        ? jsonResponse(publicTrack())
        : jsonResponse({
            url: "https://cf-media.sndcdn.com/audio.mp3"
          });
    }
  );

  const source = await adapter.resolve("42", "low", { useProxy: true });

  assert.equal(source.protocol, "progressive");
  assert.match(calls[1]?.pathname ?? "", /progressive/);
});

test("fails closed when the client requests an unconfigured proxy", async () => {
  let requested = false;
  const adapter = new SoundCloudAdapter({ clientId }, async () => {
    requested = true;
    return jsonResponse({ collection: [] });
  });

  await assert.rejects(
    () =>
      adapter.searchTracks("Tycho", 10, {
        useProxy: true
      }),
    /server proxy is not configured/
  );
  assert.equal(requested, false);
});

test("normalizes compact authenticated IPv4 proxy syntax", () => {
  assert.equal(
    normalizeProxyUrl("203.0.113.8:8080:music-user:p@ss word"),
    "http://music-user:p%40ss%20word@203.0.113.8:8080"
  );
});

test("rejects malformed compact proxy values", () => {
  assert.throws(
    () => normalizeProxyUrl("999.1.1.1:8080:user:pass"),
    /valid IPv4/
  );
  assert.throws(
    () => normalizeProxyUrl("203.0.113.8:70000:user:pass"),
    /valid IPv4/
  );
  assert.throws(
    () => normalizeProxyUrl("203.0.113.8:8080:user"),
    /ip:port:login:password/
  );
  assert.throws(
    () => normalizeProxyUrl("http://user:pass@proxy.example.com:8080"),
    /literal IPv4/
  );
  assert.throws(
    () => normalizeProxyUrl("http://user:pass@[2001:db8::1]:8080"),
    /literal IPv4/
  );
});

test("attaches the proxy dispatcher only when the toggle is enabled", async () => {
  const dispatchers: unknown[] = [];
  const adapter = new SoundCloudAdapter(
    {
      clientId,
      proxyUrl: "203.0.113.8:8080:user:pass"
    },
    async (_input, init) => {
      dispatchers.push(init?.dispatcher);
      return jsonResponse({ collection: [] });
    }
  );

  await adapter.searchTracks("direct", 1);
  await adapter.searchTracks("proxied", 1, { useProxy: true });

  assert.equal(dispatchers[0], undefined);
  assert.ok(dispatchers[1]);
});

test("rejects a resolved stream hosted outside SoundCloud domains", async () => {
  const adapter = new SoundCloudAdapter(
    { clientId },
    async (input) =>
      new URL(String(input)).pathname.startsWith("/tracks/")
        ? jsonResponse(publicTrack())
        : jsonResponse({ url: "https://attacker.example/audio.m3u8" })
  );

  await assert.rejects(
    () => adapter.resolve("42", "high"),
    /unexpected stream host/
  );
});
