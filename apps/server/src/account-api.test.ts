import assert from "node:assert/strict";
import { createServer, type Server } from "node:http";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, test } from "node:test";
import express from "express";
import { createAccountRouter } from "./account-api.js";
import { AccountStore } from "./account-store.js";

const directory = mkdtempSync(join(tmpdir(), "resonance-account-"));
const store = new AccountStore(join(directory, "account.sqlite"), "test-pepper");
let server: Server;
let baseUrl: string;

before(async () => {
  const app = express();
  app.use(express.json({ limit: "32kb" }));
  app.use("/api/v1/account", createAccountRouter(store));
  server = createServer(app);
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  assert(address && typeof address === "object");
  baseUrl = `http://127.0.0.1:${address.port}/api/v1/account`;
});

after(async () => {
  await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  store.close();
  rmSync(directory, { recursive: true, force: true });
});

const request = async (path: string, init: RequestInit = {}) => {
  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    headers: { "content-type": "application/json", ...init.headers }
  });
  const body = response.status === 204 ? undefined : await response.json();
  return { response, body };
};

test("registration, login, refresh rotation and logout are secure", async () => {
  const registered = await request("/register", {
    method: "POST",
    body: JSON.stringify({ email: " Listener@Example.com ", password: "correct horse battery", deviceName: "Tests" })
  });
  assert.equal(registered.response.status, 201);
  assert.equal(registered.body.user.email, "listener@example.com");

  const duplicate = await request("/register", {
    method: "POST",
    body: JSON.stringify({ email: "listener@example.com", password: "another secure pass", deviceName: "Tests" })
  });
  assert.equal(duplicate.response.status, 409);

  const wrong = await request("/login", {
    method: "POST",
    body: JSON.stringify({ email: "listener@example.com", password: "definitely wrong", deviceName: "Tests" })
  });
  assert.equal(wrong.response.status, 401);

  const refreshed = await request("/refresh", {
    method: "POST",
    body: JSON.stringify({ refreshToken: registered.body.refreshToken, deviceName: "Tests" })
  });
  assert.equal(refreshed.response.status, 200);
  assert.notEqual(refreshed.body.refreshToken, registered.body.refreshToken);

  const replay = await request("/refresh", {
    method: "POST",
    body: JSON.stringify({ refreshToken: registered.body.refreshToken, deviceName: "Tests" })
  });
  assert.equal(replay.response.status, 401);

  const me = await request("/me", {
    headers: { authorization: `Bearer ${refreshed.body.accessToken}` }
  });
  assert.equal(me.response.status, 200);

  const logout = await request("/logout", {
    method: "POST",
    body: JSON.stringify({ refreshToken: refreshed.body.refreshToken })
  });
  assert.equal(logout.response.status, 204);
});

test("library operations are idempotent, sanitized and user scoped", async () => {
  const first = await createUser("first@example.com");
  const second = await createUser("second@example.com");
  const favorite = {
    id: "track-1",
    title: "Track",
    normalizedTitle: "track",
    artist: "Artist",
    normalizedArtist: "artist",
    album: null,
    duration: 123000,
    artworkUrl: "https://i.example/cover.jpg",
    sources: [{
      provider: "soundcloud",
      externalId: "42",
      externalUrl: "https://soundcloud.com/a/t",
      metadata: { token: "must-not-sync" }
    }],
    preferredProvider: "soundcloud"
  };
  const operations = [
    { id: "4c625288-9490-461d-82cc-0ec6bd7bd810", type: "playlistUpsert", playlistId: "p1", name: "Mix", createdAt: "2026-08-29T00:00:00.000Z" },
    { id: "137283fa-d988-45d9-835a-28009908bef7", type: "favoriteUpsert", track: favorite },
    { id: "40d80dff-a335-44f8-b133-2575ab423012", type: "playlistTrackUpsert", playlistId: "p1", track: favorite, position: 0 }
  ];
  const synced = await request("/library/operations", {
    method: "POST",
    headers: { authorization: `Bearer ${first.accessToken}` },
    body: JSON.stringify({ operations })
  });
  assert.equal(synced.response.status, 200);
  assert.equal(synced.body.library.favorites.length, 1);
  assert.deepEqual(synced.body.library.favorites[0].sources[0].metadata, {});

  const replay = await request("/library/operations", {
    method: "POST",
    headers: { authorization: `Bearer ${first.accessToken}` },
    body: JSON.stringify({ operations })
  });
  assert.equal(replay.body.library.favorites.length, 1);
  assert.equal(replay.body.library.playlists[0].tracks.length, 1);

  const isolated = await request("/library", {
    headers: { authorization: `Bearer ${second.accessToken}` }
  });
  assert.deepEqual(isolated.body.library, { favorites: [], playlists: [] });

  const removed = await request("/library/operations", {
    method: "POST",
    headers: { authorization: `Bearer ${first.accessToken}` },
    body: JSON.stringify({ operations: [
      { id: "7d413991-ae38-418c-b6be-c39ebd140b54", type: "favoriteDelete", trackId: "track-1" },
      { id: "1a676cc6-bcca-412d-af6f-15a7542715a7", type: "playlistDelete", playlistId: "p1" }
    ] })
  });
  assert.deepEqual(removed.body.library, { favorites: [], playlists: [] });
});

async function createUser(email: string) {
  const result = await request("/register", {
    method: "POST",
    body: JSON.stringify({ email, password: "a sufficiently long password", deviceName: "Tests" })
  });
  assert.equal(result.response.status, 201);
  return result.body as { accessToken: string; refreshToken: string };
}
