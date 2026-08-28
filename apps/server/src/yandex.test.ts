import assert from "node:assert/strict";
import test from "node:test";
import { YandexAdapter } from "./yandex.js";

test("requires a Yandex token without exposing it in an error", async () => {
  const adapter = new YandexAdapter();

  await assert.rejects(
    () => adapter.searchTracks("Tycho", 10),
    (error: Error) =>
      error.message === "A Yandex Music OAuth token is required" &&
      !error.message.includes("token-value")
  );
});

test("maps Yandex search results using the request token", async () => {
  let receivedToken = "";
  const adapter = new YandexAdapter(undefined, (token) => {
    receivedToken = token;
    return {
      async search() {
        return {
          tracks: {
            results: [
              {
                id: 42,
                title: "Пачка сигарет",
                available: true,
                artists: [{ name: "Кино" }],
                albums: [{ title: "Звезда по имени Солнце" }],
                coverUri: "avatars.yandex.net/get-music-content/cover/%%",
                durationMs: 275000
              }
            ]
          }
        };
      },
      async tracksDownloadInfo() {
        return [];
      }
    };
  });

  const tracks = await adapter.searchTracks("Кино", 10, {
    token: "user-token"
  });

  assert.equal(receivedToken, "user-token");
  assert.deepEqual(tracks, [
    {
      id: "42",
      title: "Пачка сигарет",
      artist: "Кино",
      album: "Звезда по имени Солнце",
      durationMs: 275000,
      artworkUrl: "https://avatars.yandex.net/get-music-content/cover/400x400",
      externalUrl: "https://music.yandex.ru/track/42"
    }
  ]);
});

test("reports and validates the server token fallback", async () => {
  let receivedToken = "";
  const adapter = new YandexAdapter("server-token", (token) => {
    receivedToken = token;
    return {
      async search() {
        return { tracks: { results: [] } };
      },
      async tracksDownloadInfo() {
        return [];
      }
    };
  });

  assert.equal(adapter.serverCredentialConfigured, true);
  await adapter.validateAccess();
  assert.equal(receivedToken, "server-token");
});

test("selects a non-preview stream for the requested quality", async () => {
  const adapter = new YandexAdapter(
    "server-token",
    () => ({
      async search() {
        return null;
      },
      async tracksDownloadInfo() {
        return [
          {
            codec: "mp3",
            bitrateInKbps: 128,
            preview: false,
            direct: true,
            downloadInfoUrl: "https://strm.yandex.net/low.mp3",
            async getDirectLink() {
              throw new Error("direct variant should not be re-resolved");
            }
          },
          {
            codec: "aac",
            bitrateInKbps: 320,
            preview: false,
            direct: true,
            downloadInfoUrl: "https://strm.yandex.net/high.m3u8",
            async getDirectLink() {
              throw new Error("direct variant should not be re-resolved");
            }
          }
        ];
      }
    }),
    () => 1_000
  );

  const high = await adapter.resolve("42", "high");
  const low = await adapter.resolve("42", "low");

  assert.equal(high.streamUrl, "https://strm.yandex.net/high.m3u8");
  assert.equal(high.protocol, "hls");
  assert.equal(high.bitrate, 320_000);
  assert.equal(low.streamUrl, "https://strm.yandex.net/low.mp3");
  assert.equal(low.protocol, "progressive");
});

test("rejects a Yandex stream hosted on an unexpected domain", async () => {
  const adapter = new YandexAdapter("server-token", () => ({
    async search() {
      return null;
    },
    async tracksDownloadInfo() {
      return [
        {
          codec: "mp3",
          bitrateInKbps: 320,
          preview: false,
          direct: true,
          downloadInfoUrl: "https://attacker.example/audio.mp3",
          async getDirectLink() {
            return "https://attacker.example/audio.mp3";
          }
        }
      ];
    }
  }));

  await assert.rejects(
    () => adapter.resolve("42", "high"),
    /unexpected stream host/
  );
});

test("imports a Yandex playlist preserving track order", async () => {
  const adapter = new YandexAdapter("server-token", () => ({
    async search() { return null; },
    async tracksDownloadInfo() { return []; },
    async usersPlaylists(kind, owner) {
      assert.equal(kind, "7");
      assert.equal(owner, "listener");
      return {
        title: "В дорогу",
        tracks: [
          { id: 2, track: { id: 2, title: "Second", artist: "Artist", available: true, artists: [{ name: "B" }] } },
          { id: 1, track: { id: 1, title: "First", artist: "Artist", available: true, artists: [{ name: "A" }] } }
        ]
      };
    },
    async playlist() { return null; },
    async tracks() { return []; }
  }));

  const playlist = await adapter.importPlaylist({ owner: "listener", kind: "7" });
  assert.equal(playlist.title, "В дорогу");
  assert.deepEqual(playlist.tracks.map((track) => track.id), ["2", "1"]);
});
