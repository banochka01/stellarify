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

test("reports the official VK limitation instead of scraping private APIs", async () => {
  const service = new PlaylistImportService({} as never, {} as never);
  await assert.rejects(() => service.importUrl("https://vk.com/music/playlist/1_2"), /public playlist API/u);
});
