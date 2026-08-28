import assert from "node:assert/strict";
import test from "node:test";
import {
  type MusicProviderAdapter,
  ProviderGateway
} from "./provider-gateway.js";

test("reports official-player providers without direct playback", () => {
  const adapter: MusicProviderAdapter = {
    name: "youtube",
    configured: true,
    directPlayback: false,
    authentication: "user_token",
    async searchTracks() {
      return [];
    },
    async resolve() {
      throw new Error("official player only");
    }
  };

  const [provider] = new ProviderGateway([adapter]).listProviders();

  assert.ok(provider);
  assert.equal(provider.serverCredentialConfigured, false);
  assert.equal(provider.capabilities.search, true);
  assert.equal(provider.capabilities.playback, false);
});

test("caches a resolved stream for repeated playback requests", async () => {
  let resolves = 0;
  const adapter: MusicProviderAdapter = {
    name: "soundcloud",
    configured: true,
    authentication: "server_credentials",
    async searchTracks() {
      return [];
    },
    async resolve() {
      resolves += 1;
      return {
        streamUrl: "https://cf-hls-media.sndcdn.com/audio.m3u8",
        protocol: "hls"
      };
    }
  };
  const gateway = new ProviderGateway([adapter], () => 1_000);

  const first = await gateway.resolve("soundcloud", "42", "high");
  const second = await gateway.resolve("soundcloud", "42", "high");

  assert.equal(resolves, 1);
  assert.equal(second, first);
});

test("does not share resolved URLs between user credential scopes", async () => {
  let resolves = 0;
  const adapter: MusicProviderAdapter = {
    name: "yandex",
    configured: true,
    authentication: "user_token",
    async searchTracks() {
      return [];
    },
    async resolve() {
      resolves += 1;
      return {
        streamUrl: `https://strm.yandex.net/audio-${resolves}.mp3`,
        protocol: "progressive"
      };
    }
  };
  const gateway = new ProviderGateway([adapter], () => 1_000);

  await gateway.resolve("yandex", "42", "high", { cacheScope: "user-a" });
  await gateway.resolve("yandex", "42", "high", { cacheScope: "user-b" });

  assert.equal(resolves, 2);
});
