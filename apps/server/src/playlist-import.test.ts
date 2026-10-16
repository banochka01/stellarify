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

test("unwraps a Dotify share link into the wrapped provider URL", async () => {
  const references: unknown[] = [];
  const yandex = { importPlaylist: async (reference: unknown) => { references.push(reference); return { provider: "yandex", externalId: "x", title: "Мне нравится", tracks: [] }; } };
  const target = "https://music.yandex.ru/playlists/lk.5e6c5a06-205e-4504-ad23-accef83c8a50?utm_medium=copy_link";
  const html = `<a href="dotify://playlist/library/${Buffer.from(target).toString("base64")}">Открыть</a>`;
  let fetched = "";
  const fetcher = (async (url: string) => { fetched = url; return new Response(html); }) as unknown as typeof fetch;
  const service = new PlaylistImportService(yandex as never, {} as never, undefined, undefined, fetcher);
  const result = await service.importUrl("https://share.dotify.fun/KnhitFbw");
  assert.equal(fetched, "https://share.dotify.fun/KnhitFbw");
  assert.deepEqual(references, [{ uuid: "lk.5e6c5a06-205e-4504-ad23-accef83c8a50" }]);
  assert.equal(result.title, "Мне нравится");
});

test("matches the public track preview of a Dotify-only playlist on SoundCloud", async () => {
  const html = `<h2 class="title">Мне нравится</h2>
    <div class="track-name">VLNY - Танцы В Темноте</div>
    <div class="track-artist">_sevase_</div>
    <a href="dotify://playlist/library/99049705-b618-4a8d-a2a0-832dd7a6aabb">`;
  const queries: string[] = [];
  const soundcloud = { searchTracks: async (query: string) => { queries.push(query); return [{ id: "1", title: "Танцы" }]; } };
  const fetcher = (async () => new Response(html)) as unknown as typeof fetch;
  const service = new PlaylistImportService({} as never, {} as never, undefined, undefined, fetcher, soundcloud as never);
  const result = await service.importUrl("https://share.dotify.fun/CSG6NPOx");
  assert.deepEqual(queries, ["_sevase_ VLNY - Танцы В Темноте"]);
  assert.equal(result.provider, "soundcloud");
  assert.equal(result.title, "Мне нравится");
  assert.equal(result.tracks.length, 1);
});
