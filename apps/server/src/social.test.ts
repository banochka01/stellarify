import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import type { WaveBlock, WaveTasteSignals } from "./account-store.js";
import { openSqlite } from "./api-helpers.js";
import type { DailyMixInput } from "./daily-mixes.js";
import { artistWeights, compatibility, createSocialRouter, SocialService } from "./social.js";
import { SocialStore } from "./social-store.js";
import { headerAuth, serveRouter } from "./test-http.js";

const now = Date.parse("2026-10-13T12:00:00Z");
const listen = (artist: string, title = "Song", minutesAgo = 1) => ({
  type: "finished" as const, provider: "soundcloud" as const, trackId: `${artist}-${title}`, title, artist,
  playedDurationMs: 200_000, createdAt: new Date(now - minutesAgo * 60_000).toISOString()
});
const tastes: Record<string, WaveTasteSignals> = {
  alice: { listening: [listen("Кино"), listen("Radiohead"), listen("Björk")], favorites: [{ title: "A", artist: "Кино" }], playlistTracks: [{ title: "B", artist: "Muse" }] },
  bob: { listening: [listen("Kino", "Группа крови", 2), listen("Radiohead"), listen("Daft Punk")], favorites: [], playlistTracks: [] },
  carol: { listening: [], favorites: [], playlistTracks: [] }
};
const blocks: Record<string, WaveBlock[]> = {
  bob: [{ kind: "artist", key: "nickelback", label: "Nickelback", removed: false, updatedAt: new Date(now).toISOString() }]
};
let mixInput: DailyMixInput | undefined;
let historyQueries = 0;
const taste = {
  getWaveTasteSignals: (id: string) => tastes[id] ?? { listening: [], favorites: [], playlistTracks: [] },
  getWaveBlocks: (id: string) => blocks[id] ?? [],
  recentListening: (ids: string[]) => {
    historyQueries += 1;
    return new Map(ids.map((id) => [id, (tastes[id]?.listening ?? []).map((item) => ({ title: item.title, artist: item.artist, createdAt: item.createdAt }))]));
  }
};
const service = new SocialService(
  new SocialStore(openSqlite(":memory:"), () => now),
  taste,
  {
    build: async (owner, input) => {
      mixInput = input;
      return { day: "2026-10-13", refreshedAt: "", nextRefreshAt: "2026-10-14T03:00:00.000Z", mixes: [{ id: `${owner}:morning`, kind: "morning", title: "Утро", subtitle: "", seedArtists: input.favoriteArtists.slice(0, 3), tracks: [] }] };
    }
  },
  {
    live: (ids) => ids.includes("bob") ? [{ userId: "bob", code: "ABC123", isPrivate: true, participants: 3, track: { title: "T", artist: "A" } }] : [],
    isMember: () => false
  },
  () => now,
  { feedCacheMs: 0 }
);
let api: Awaited<ReturnType<typeof serveRouter>>;
before(async () => { api = await serveRouter("/api/v1/social", createSocialRouter(service, headerAuth)); });
after(async () => { service.stop(); await api.close(); });

test("compatibility uses transliteration-aware artist overlap", () => {
  const result = compatibility(artistWeights(tastes.alice!), artistWeights(tastes.bob!));
  assert.ok(result.percent > 30 && result.percent <= 100, String(result.percent));
  assert.ok(result.sharedArtists.includes("Кино") || result.sharedArtists.includes("Kino"));
  assert.ok(result.sharedArtists.includes("Radiohead"));
  assert.deepEqual(compatibility(artistWeights(tastes.alice!), artistWeights(tastes.carol!)).percent, 0);
  assert.equal(compatibility(artistWeights(tastes.alice!), artistWeights(tastes.alice!)).percent, 100);
});

test("social routes require an account", async () => {
  assert.equal((await api.call("GET", "/profile")).status, 401);
});

test("profiles are hidden by default and friendship needs request + accept", async () => {
  const profile = await api.call("GET", "/profile", "alice");
  assert.equal(profile.status, 200);
  assert.equal(profile.body.profile.isPublic, false);
  assert.equal(profile.body.profile.shareListening, false);
  await api.call("GET", "/profile", "bob");
  assert.deepEqual((await api.call("GET", "/users/search?q=bo", "alice")).body.users, []);
  assert.equal((await api.call("POST", "/friends/requests", "alice", { handle: "bobby" })).status, 404);

  const patched = await api.call("PATCH", "/profile", "bob", { displayName: "Боб", handle: "Bobby", isPublic: true });
  assert.equal(patched.body.profile.handle, "bobby");
  assert.equal((await api.call("PATCH", "/profile", "alice", { handle: "bobby" })).status, 409);
  assert.equal((await api.call("PATCH", "/profile", "alice", { handle: "no spaces" })).status, 400);
  assert.equal((await api.call("GET", "/users/search?q=bob", "alice")).body.users[0].userId, "bob");

  assert.equal((await api.call("GET", "/compatibility/bob", "alice")).status, 403);
  const requested = await api.call("POST", "/friends/requests", "alice", { handle: "bobby" });
  assert.equal(requested.body.relation, "outgoing");
  const incoming = await api.call("GET", "/friends", "bob");
  assert.equal(incoming.body.incoming[0].userId, "alice");
  assert.equal((await api.call("POST", "/friends/requests/alice/accept", "bob")).body.relation, "friends");
  assert.equal((await api.call("GET", "/friends", "alice")).body.friends[0].displayName, "Боб");
  const match = await api.call("GET", "/compatibility/bob", "alice");
  assert.equal(match.status, 200);
  assert.ok(match.body.compatibility.percent > 0);
  // Bob does not share listening: only the percentage, no artists.
  assert.deepEqual(match.body.compatibility.sharedArtists, []);
  assert.equal((await api.call("POST", "/blend/bob", "alice", {})).status, 403);
});

test("feed shows only friends who opted in, private rooms without a code", async () => {
  assert.deepEqual((await api.call("GET", "/feed", "alice")).body.items, []);
  await api.call("PATCH", "/profile", "bob", { shareListening: true, shareRooms: true });
  await api.call("PUT", "/now-playing", "bob", { title: "Idioteque", artist: "Radiohead" });
  const queriesBefore = historyQueries;
  const feed = await api.call("GET", "/feed", "alice");
  assert.equal(historyQueries - queriesBefore, 1, "one history query for all friends");
  assert.equal(feed.body.items.length, 1);
  const item = feed.body.items[0];
  assert.equal(item.friend.userId, "bob");
  assert.equal(item.nowPlaying.title, "Idioteque");
  assert.ok(item.recent.length >= 1);
  assert.deepEqual(item.room, { code: null, isPrivate: true, participants: 3, track: null });
  // Not friends → nothing even when sharing.
  assert.deepEqual((await api.call("GET", "/feed", "carol")).body.items, []);
});

test("blend builds a shared mix from both tastes and both block lists", async () => {
  const blend = await api.call("POST", "/blend/bob", "alice", { enabledProviders: ["soundcloud"] });
  assert.equal(blend.status, 200);
  assert.match(blend.body.title, /Blend/);
  assert.ok(blend.body.mixes[0].id.startsWith("blend:"));
  assert.ok(mixInput?.favoriteArtists.includes("Daft Punk"));
  assert.ok(mixInput?.favoriteArtists.includes("Muse"));
  // The friend's private block list is never used.
  assert.deepEqual(mixInput?.blockedArtists, []);
  assert.ok((await api.call("GET", "/compatibility/bob", "alice")).body.compatibility.sharedArtists.length > 0);
  assert.equal((await api.call("POST", "/blend/carol", "alice", {})).status, 403);
});

test("invite codes reach hidden profiles; blocking removes friendship and stops requests", async () => {
  const carol = await api.call("GET", "/profile", "carol");
  const viaInvite = await api.call("POST", "/friends/requests", "alice", { inviteCode: carol.body.profile.inviteCode });
  assert.equal(viaInvite.body.relation, "outgoing");
  assert.equal((await api.call("DELETE", "/friends/requests/alice", "carol")).status, 204);
  assert.equal((await api.call("GET", "/friends", "alice")).body.outgoing.length, 0);

  assert.equal((await api.call("POST", "/blocks", "bob", { userId: "alice" })).status, 204);
  assert.equal((await api.call("GET", "/friends", "alice")).body.friends.length, 0);
  assert.equal((await api.call("POST", "/friends/requests", "alice", { handle: "bobby" })).status, 404);
  assert.deepEqual((await api.call("GET", "/users/search?q=bob", "alice")).body.users, []);
  assert.equal((await api.call("DELETE", "/blocks/alice", "bob")).status, 204);
  assert.equal((await api.call("POST", "/friends/requests", "alice", { handle: "bobby" })).body.relation, "outgoing");
  // A reverse request auto-accepts.
  assert.equal((await api.call("POST", "/friends/requests", "bob", { userId: "alice" })).body.relation, "friends");
  assert.equal((await api.call("DELETE", "/friends/alice", "bob")).status, 204);
  assert.equal((await api.call("GET", "/friends", "bob")).body.friends.length, 0);
});

test("handle changes are limited to 5 per hour", async () => {
  for (let index = 0; index < 5; index += 1) {
    assert.equal((await api.call("PATCH", "/profile", "dave", { handle: `dave_${index}` })).status, 200);
  }
  assert.equal((await api.call("PATCH", "/profile", "dave", { handle: "dave_x" })).status, 429);
  // Other profile fields stay editable.
  assert.equal((await api.call("PATCH", "/profile", "dave", { displayName: "Дэйв" })).status, 200);
});

test("now playing has a hard size cap that evicts the oldest", () => {
  const small = new SocialService(new SocialStore(openSqlite(":memory:")), taste, { build: async () => { throw new Error("unused"); } },
    { live: () => [], isMember: () => false }, Date.now, { maxNowPlaying: 2 });
  small.setNowPlaying("u1", { title: "a", artist: "b" });
  small.setNowPlaying("u2", { title: "a", artist: "b" });
  small.setNowPlaying("u1", { title: "c", artist: "d" });
  small.setNowPlaying("u3", { title: "a", artist: "b" });
  assert.equal(small.nowPlayingSize, 2);
  small.stop();
});

test("accept respects the requester's friend limit too", () => {
  const store = new SocialStore(openSqlite(":memory:"));
  for (let index = 0; index < 1_000; index += 1) {
    store.request(`f${index}`, "popular");
    store.accept("popular", `f${index}`);
  }
  store.request("popular", "newbie");
  assert.throws(() => store.accept("newbie", "popular"), /лимит/);
});
