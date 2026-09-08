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

test("accepts current Yandex stable playlist URLs", async () => {
  const references: unknown[] = [];
  const yandex = { importPlaylist: async (reference: unknown) => {
    references.push(reference);
    return { provider: "yandex", externalId: "uuid", title: "Mix", tracks: [] };
  } };
  const service = new PlaylistImportService(yandex as never, {} as never);

  await service.importUrl("https://music.yandex.ru/playlists/1f44703c-a7cf-4f93-bd6d-3e9a312beef0");
  await service.importUrl("https://music.yandex.ru/playlist/legacy-uuid?utm_source=share");
  await service.importUrl("https://music.yandex.ru/handlers/playlist.jsx?playlistUuid=query-uuid");

  assert.deepEqual(references, [
    { uuid: "1f44703c-a7cf-4f93-bd6d-3e9a312beef0" },
    { uuid: "legacy-uuid" },
    { uuid: "query-uuid" }
  ]);
});

test("imports VK playlists by parsing the playlist reference from the URL", async () => {
  let received: unknown;
  const vk = { importPlaylist: async (reference: unknown) => { received = reference; return { provider: "vk", externalId: "1_2", title: "VK плейлист 1_2", tracks: [] }; } };
  const service = new PlaylistImportService({} as never, {} as never, undefined, vk as never);
  const result = await service.importUrl("https://vk.com/music/playlist/1_2");
  assert.deepEqual(received, { owner: "1", playlist: "2" });
  assert.equal(result.title, "VK плейлист 1_2");
});
