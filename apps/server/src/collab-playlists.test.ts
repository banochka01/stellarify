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

test("unfriend and block remove shared memberships; blocked members lose access", async () => {
  const { SocialStore } = await import("./social-store.js");
  const db = openSqlite(":memory:");
  const social = new SocialStore(db);
  const collab = new CollabPlaylistStore(db, Date.now, (a, b) => social.isBlockedEitherWay(a, b));
  social.onRelationshipEnded((a, b) => collab.removeSharedMemberships(a, b));
  const befriend = (a: string, b: string) => { social.request(a, b); social.accept(b, a); };
  befriend("ann", "ben");
  befriend("ann", "cat");
  const mine = collab.create("ann", "Ann's");
  const his = collab.create("ben", "Ben's");
  collab.setMember(mine.id, "ann", "ben", "editor");
  collab.setMember(his.id, "ben", "ann", "viewer");
  collab.setMember(mine.id, "ann", "cat", "viewer");

  social.removeFriend("ben", "ann");
  assert.equal(collab.role(mine.id, "ben"), undefined);
  assert.equal(collab.role(his.id, "ann"), undefined);

  // Even if a membership row survives, a block denies access.
  db.prepare("INSERT INTO social_blocks (user_id, blocked_id, created_at) VALUES (?, ?, ?)").run("cat", "ann", Date.now());
  assert.throws(() => collab.get(mine.id, "cat"), /не найден/);
  assert.equal(collab.list("cat").length, 0);
  social.block("ann", "cat");
  assert.equal(Number((db.prepare("SELECT COUNT(*) AS c FROM collab_members WHERE user_id = 'cat'").get() as { c: number }).c), 0);
});

test("revert of a removal respects the track limit; list reports roles in one query", () => {
  const store = new CollabPlaylistStore(openSqlite(":memory:"), Date.now, () => false, 2);
  const playlist = store.create("o", "Small");
  const first = store.addTrack(playlist.id, "o", track("1"));
  store.removeTrack(playlist.id, "o", first.entryId);
  store.addTrack(playlist.id, "o", track("2"));
  store.addTrack(playlist.id, "o", track("3"));
  const removal = store.history(playlist.id, "o").find((entry) => entry.action === "remove")!;
  assert.throws(() => store.revert(playlist.id, "o", removal.id), /слишком много/);
  store.setMember(playlist.id, "o", "m", "editor");
  assert.deepEqual(store.list("m").map((entry) => entry.role), ["editor"]);
  assert.deepEqual(store.list("o").map((entry) => entry.role), ["owner"]);
});
