import assert from "node:assert/strict";
import test from "node:test";
import { PlaylistImportService } from "./playlist-import.js";

test("extracts owner and kind from a Yandex playlist URL", async () => {
  let received: unknown;
  const yandex = { importPlaylist: async (reference: unknown) => { received = reference; return { provider: "yandex", externalId: "owner:7", title: "Mix", tracks: [] }; } };
  const service = new PlaylistImportService(yandex as never, {} as never);
  const result = await service.importUrl("https://music.yandex.ru/users/owner/playlists/7");
  assert.deepEqual(received, { owner: "owner", kind: "7" });
  assert.equal(result.title, "Mix");
});

test("imports VK playlists by parsing the playlist reference from the URL", async () => {
  let received: unknown;
  const vk = { importPlaylist: async (reference: unknown) => { received = reference; return { provider: "vk", externalId: "1_2", title: "VK плейлист 1_2", tracks: [] }; } };
  const service = new PlaylistImportService({} as never, {} as never, undefined, vk as never);
  const result = await service.importUrl("https://vk.com/music/playlist/1_2");
  assert.deepEqual(received, { owner: "1", playlist: "2" });
  assert.equal(result.title, "VK плейлист 1_2");
});
