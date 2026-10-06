import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";
import test from "node:test";
import express from "express";
import { ArtistService, createArtistRouter, normalizeArtistName } from "./artists.js";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });

const deezer = (url: URL): Response => {
  if (url.pathname === "/search/artist") {
    return json({ data: [
      { id: 1, name: "Pure Snow Tribute", nb_fan: 999999 },
      { id: 42, name: "PureSnow", nb_fan: 151700, nb_album: 9, picture_xl: "https://cdn.example/a.jpg", link: "https://www.deezer.com/artist/42" }
    ] });
  }
  if (url.pathname === "/artist/42/top") {
    return json({ data: [
      { id: 7, title: "TEETH", duration: 150, artist: { name: "PureSnow" }, album: { title: "Oaths", cover_xl: "https://cdn.example/oaths.jpg" } },
      { broken: true }
    ] });
  }
  if (url.pathname === "/artist/42/albums") {
    return json({ data: [
      { id: 10, title: "Oaths", cover_xl: "https://cdn.example/oaths.jpg", release_date: "2026-03-18", record_type: "album" },
      { id: 11, title: "Oaths", cover_xl: "https://cdn.example/oaths2.jpg", release_date: "2026-03-18", record_type: "album" },
      { id: 12, title: "Limbo", cover_xl: "http://insecure.example/limbo.jpg", record_type: "single" }
    ] });
  }
  if (url.pathname === "/artist/42/related") {
    return json({ data: [{ id: 5, name: "Friend", picture_xl: "https://cdn.example/f.jpg", nb_fan: 12 }] });
  }
  if (url.pathname === "/album/10") {
    return json({
      id: 10, title: "Oaths", cover_xl: "https://cdn.example/oaths.jpg", record_type: "album",
      artist: { name: "PureSnow" },
      tracks: { data: [{ id: 70, title: "Intro", duration: 60 }, { id: 71, title: "TEETH", duration: 150 }] }
    });
  }
  return json({ error: { type: "DataException", message: "no data" } });
};

test("normalizes artist names for matching", () => {
  assert.equal(normalizeArtistName("The  Pure-Snow!"), "puresnow");
  assert.equal(normalizeArtistName("ЛСП"), "лсп");
});

test("builds a Deezer profile with the exact artist, top tracks, deduplicated albums and related", async () => {
  const service = new ArtistService(async (input) => deezer(new URL(String(input))));
  const profile = await service.profile("puresnow");
  assert.equal(profile.artist.id, "deezer:42");
  assert.equal(profile.artist.fans, 151700);
  assert.equal(profile.artist.source, "deezer");
  assert.deepEqual(profile.topTracks.map((track) => track.title), ["TEETH"]);
  assert.equal(profile.topTracks[0]?.durationMs, 150000);
  assert.equal(profile.topTracks[0]?.artworkUrl, "https://cdn.example/oaths.jpg");
  assert.deepEqual(profile.albums.map((album) => album.title), ["Oaths", "Limbo"]);
  assert.equal(profile.albums[1]?.artworkUrl, undefined);
  assert.equal(profile.albums[1]?.type, "single");
  assert.equal(profile.related[0]?.name, "Friend");
});

test("caches profiles and coalesces concurrent requests", async () => {
  let calls = 0;
  const service = new ArtistService(async (input) => {
    calls++;
    await new Promise((resolve) => setTimeout(resolve, 2));
    return deezer(new URL(String(input)));
  });
  await Promise.all([service.profile("PureSnow"), service.profile("puresnow")]);
  const before = calls;
  await service.profile("PURESNOW");
  assert.equal(calls, before);
  assert.equal(before, 4);
});

test("falls back to iTunes when Deezer is unavailable", async () => {
  const service = new ArtistService(async (input) => {
    const url = new URL(String(input));
    if (url.hostname === "api.deezer.com") throw new Error("offline");
    if (url.pathname === "/search") {
      return json({ results: [{ wrapperType: "artist", artistId: 3, artistName: "Signal" }] });
    }
    if (url.searchParams.get("entity") === "song") {
      return json({ results: [
        { wrapperType: "artist", artistId: 3, artistName: "Signal" },
        { wrapperType: "track", kind: "song", trackId: 9, trackName: "Wave", artistName: "Signal", artworkUrl100: "https://is1.example/a/100x100bb.jpg", trackTimeMillis: 1000 }
      ] });
    }
    return json({ results: [
      { wrapperType: "collection", collectionId: 4, collectionName: "Old - EP", releaseDate: "2020-01-01T00:00:00Z", artworkUrl100: "https://is1.example/b/100x100bb.jpg" },
      { wrapperType: "collection", collectionId: 5, collectionName: "New", releaseDate: "2025-01-01T00:00:00Z", trackCount: 10 }
    ] });
  });
  const profile = await service.profile("signal");
  assert.equal(profile.artist.source, "itunes");
  assert.equal(profile.topTracks[0]?.artworkUrl, "https://is1.example/a/600x600bb.jpg");
  assert.deepEqual(profile.albums.map((album) => [album.title, album.type]), [["New", "album"], ["Old", "ep"]]);
  assert.equal(profile.albums[1]?.releaseDate, "2020-01-01");
});

test("reports missing artists and unavailable sources without caching failures", async () => {
  let offline = true;
  const service = new ArtistService(async (input) => {
    if (offline) throw new Error("offline");
    return deezer(new URL(String(input)));
  });
  await assert.rejects(service.profile("PureSnow"), { status: 502 });
  offline = false;
  assert.equal((await service.profile("PureSnow")).artist.name, "PureSnow");
  await assert.rejects(new ArtistService(async () => json({ data: [], results: [] })).profile("nobody"), { status: 404 });
});

test("serves profile and album routes with validation", async () => {
  const app = express();
  app.use("/api/v1/artists", createArtistRouter(new ArtistService(async (input) => deezer(new URL(String(input))))));
  const server = createServer(app).listen(0);
  await once(server, "listening");
  const address = server.address();
  assert.ok(address && typeof address === "object");
  const base = `http://127.0.0.1:${address.port}/api/v1/artists`;
  try {
    const profile = await fetch(`${base}?name=PureSnow`);
    assert.equal(profile.status, 200);
    assert.equal((await profile.json() as { artist: { name: string } }).artist.name, "PureSnow");
    const album = await fetch(`${base}/albums/deezer:10`);
    const body = await album.json() as { tracks: { title: string }[]; album: { artist: string } };
    assert.deepEqual(body.tracks.map((track) => track.title), ["Intro", "TEETH"]);
    assert.equal(body.album.artist, "PureSnow");
    assert.equal((await fetch(`${base}?name=`)).status, 400);
    assert.equal((await fetch(`${base}/albums/spotify:1`)).status, 400);
  } finally {
    server.close();
  }
});
