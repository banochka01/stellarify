import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { openSqlite } from "./api-helpers.js";
import { CollabPlaylistStore, createCollabPlaylistRouter } from "./collab-playlists.js";
import { headerAuth, serveRouter } from "./test-http.js";

const friends = new Set(["owner:editor", "owner:viewer"]);
let api: Awaited<ReturnType<typeof serveRouter>>;
before(async () => {
  api = await serveRouter("/api/v1/collab-playlists", createCollabPlaylistRouter(
    new CollabPlaylistStore(openSqlite(":memory:")),
    headerAuth,
    (owner, member) => friends.has(`${owner}:${member}`)
  ));
});
after(async () => api.close());

const track = (id: string) => ({ id, title: `Song ${id}`, artist: "Artist", sources: [] });

test("members, roles, history and revert", async () => {
  assert.equal((await api.call("GET", "/")).status, 401);
  const created = await api.call("POST", "/", "owner", { name: "Дорога" });
  assert.equal(created.status, 201);
  const id = created.body.playlist.id as string;

  assert.equal((await api.call("GET", `/${id}`, "stranger")).status, 404);
  assert.equal((await api.call("PUT", `/${id}/members/stranger`, "owner", { role: "editor" })).status, 403);
  assert.equal((await api.call("PUT", `/${id}/members/editor`, "owner", { role: "editor" })).status, 200);
  assert.equal((await api.call("PUT", `/${id}/members/viewer`, "owner", { role: "viewer" })).status, 200);
  assert.equal((await api.call("PUT", `/${id}/members/viewer`, "editor", { role: "editor" })).status, 403);

  const first = await api.call("POST", `/${id}/tracks`, "editor", { track: track("1") });
  assert.equal(first.status, 201);
  await api.call("POST", `/${id}/tracks`, "owner", { track: track("2") });
  assert.equal((await api.call("POST", `/${id}/tracks`, "viewer", { track: track("3") })).status, 403);
  assert.equal((await api.call("POST", `/${id}/tracks`, "editor", { track: { id: "x" } })).status, 400);

  assert.equal((await api.call("DELETE", `/${id}/tracks/${first.body.entry.entryId}`, "owner")).status, 204);
  await api.call("PATCH", `/${id}`, "editor", { name: "Дорога домой" });

  const history = (await api.call("GET", `/${id}/history`, "viewer")).body.history;
  assert.deepEqual(history.map((entry: { action: string }) => entry.action), ["rename", "remove", "add", "add"]);
  assert.equal(history[1].userId, "owner");
  assert.equal(history[3].userId, "editor");

  // Undo the removal: the track returns with the same entry id.
  const reverted = await api.call("POST", `/${id}/history/${history[1].id}/revert`, "editor");
  assert.equal(reverted.status, 200);
  assert.deepEqual(reverted.body.playlist.tracks.map((entry: { track: { id: string } }) => entry.track.id), ["1", "2"]);
  assert.equal((await api.call("POST", `/${id}/history/${history[1].id}/revert`, "editor")).status, 409);
  const renamedBack = await api.call("POST", `/${id}/history/${history[0].id}/revert`, "owner");
  assert.equal(renamedBack.body.playlist.name, "Дорога");
  assert.equal((await api.call("POST", `/${id}/history/${history[0].id}/revert`, "viewer")).status, 403);

  const list = await api.call("GET", "/", "viewer");
  assert.equal(list.body.playlists[0].role, "viewer");
  assert.equal(list.body.playlists[0].trackCount, 2);

  assert.equal((await api.call("DELETE", `/${id}/members/viewer`, "viewer")).status, 204);
  assert.equal((await api.call("GET", `/${id}`, "viewer")).status, 404);
  assert.equal((await api.call("DELETE", `/${id}`, "editor")).status, 403);
  assert.equal((await api.call("DELETE", `/${id}`, "owner")).status, 204);
  assert.equal((await api.call("GET", `/${id}`, "owner")).status, 404);
});
