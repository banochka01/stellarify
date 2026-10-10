import assert from "node:assert/strict";
import { createServer } from "node:http";
import { after, before, test } from "node:test";
import { io as createClient, type Socket as ClientSocket } from "socket.io-client";
import { Server } from "socket.io";
import { registerRoomHandlers, resetLiveRoomsForTests, roomWaveUserIds } from "./rooms.js";

let io: Server;
let url: string;
const clients: ClientSocket[] = [];

before(async () => {
  const http = createServer();
  io = new Server(http);
  io.on("connection", (socket) => {
    socket.data.userId = socket.handshake.auth.userId;
    registerRoomHandlers(io, socket);
  });
  await new Promise<void>((resolve) => http.listen(0, "127.0.0.1", resolve));
  const address = http.address();
  assert(address && typeof address === "object");
  url = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  for (const client of clients) client.disconnect();
  await io.close();
});

const connect = async (userId?: string) => {
  const client = createClient(url, { transports: ["websocket"], auth: { userId } });
  clients.push(client);
  await new Promise<void>((resolve, reject) => {
    client.once("connect", resolve);
    client.once("connect_error", reject);
  });
  return client;
};

const emitAck = <T>(socket: ClientSocket, event: string, payload: unknown) =>
  new Promise<T>((resolve) => socket.emit(event, payload, resolve));

test("host and guest share a sanitized track and playback state", async () => {
  const host = await connect("host-user");
  const guest = await connect("guest-user");
  const created = await emitAck<any>(host, "room:create", { name: "Host" });
  assert.equal(created.ok, true);
  const code = created.room.code as string;

  const joined = await emitAck<any>(guest, "room:join", { code, name: "Friend" });
  assert.equal(joined.ok, true);
  assert.equal(joined.room.participants.length, 2);
  assert.equal(joined.room.participants.some((participant: any) => "userId" in participant), false);
  assert.deepEqual(roomWaveUserIds(code, "host-user"), ["host-user", "guest-user"]);
  assert.deepEqual(roomWaveUserIds(code, "guest-user"), []);

  const nextState = new Promise<any>((resolve) => guest.once("room:state", resolve));
  const updated = await emitAck<any>(host, "playback:update", {
    code,
    paused: false,
    positionMs: 12_345,
    track: {
      id: "soundcloud:42",
      title: "Track",
      normalizedTitle: "track",
      artist: "Artist",
      normalizedArtist: "artist",
      artworkUrl: "https://i.example/cover.jpg",
      sources: [{
        provider: "soundcloud",
        externalId: "42",
        externalUrl: "https://soundcloud.com/artist/track",
        metadata: { secret: "must-not-cross-room" }
      }],
      preferredProvider: "soundcloud"
    }
  });
  assert.equal(updated.ok, true);
  const state = await nextState;
  assert.equal(state.playback.track.id, "soundcloud:42");
  assert.equal(state.playback.positionMs, 12_345);
  assert.deepEqual(state.playback.track.sources[0].metadata, {});

  const denied = await emitAck<any>(guest, "playback:update", { code });
  assert.equal(denied.ok, false);
  assert.match(denied.error, /ведущий/iu);
});

const roomTrack = (id: string) => ({
  id,
  title: `Track ${id}`,
  normalizedTitle: `track ${id}`,
  artist: "Artist",
  normalizedArtist: "artist",
  sources: [{
    provider: "vk",
    externalId: id,
    externalUrl: `https://vk.com/audio${id}`
  }],
  preferredProvider: "vk"
});

test("shared queue: add, vote, host plays the top-voted entry next", async () => {
  const host = await connect("host-2");
  const guest = await connect("guest-2");
  const created = await emitAck<any>(host, "room:create", { name: "Host" });
  const code = created.room.code as string;
  await emitAck<any>(guest, "room:join", { code, name: "Friend" });

  const stateA = new Promise<any>((resolve) => guest.once("room:state", resolve));
  const addedA = await emitAck<any>(guest, "room:queue-add", { code, track: roomTrack("vk:1") });
  assert.equal(addedA.ok, true);
  assert.equal((await stateA).queue.length, 1);

  const stateB = new Promise<any>((resolve) => guest.once("room:state", resolve));
  const addedB = await emitAck<any>(host, "room:queue-add", { code, track: roomTrack("vk:2") });
  assert.equal(addedB.ok, true);
  const state = await stateB;
  assert.equal(state.queue.length, 2);

  const duplicate = await emitAck<any>(guest, "room:queue-add", { code, track: roomTrack("vk:1") });
  assert.equal(duplicate.ok, false);
  assert.match(duplicate.error, /уже в очереди/iu);

  // Guest votes for the host's entry: the adder's implicit self-vote makes it 2.
  const entryB = state.queue.find((entry: any) => entry.track.id === "vk:2");
  const stateVote = new Promise<any>((resolve) => host.once("room:state", resolve));
  const voted = await emitAck<any>(guest, "room:queue-vote", { code, entryId: entryB.id });
  assert.equal(voted.ok, true);
  assert.equal((await stateVote).queue.find((entry: any) => entry.track.id === "vk:2").votes, 2);

  // Strangers cannot vote from outside the room.
  const outsider = await connect("outsider-2");
  const outsideVote = await emitAck<any>(outsider, "room:queue-vote", { code, entryId: entryB.id });
  assert.equal(outsideVote.ok, false);

  // Host plays next: the entry with the most votes (vk:2) becomes playback.
  const stateNext = new Promise<any>((resolve) => guest.once("room:state", resolve));
  const next = await emitAck<any>(host, "room:queue-next", { code });
  assert.equal(next.ok, true);
  assert.equal(next.trackId, "vk:2");
  const finalState = await stateNext;
  assert.equal(finalState.playback.track.id, "vk:2");
  assert.equal(finalState.playback.paused, false);
  assert.equal(finalState.queue.length, 1);
  assert.equal(finalState.queue[0].track.id, "vk:1");

  // Guests cannot force "next".
  const guestNext = await emitAck<any>(guest, "room:queue-next", { code });
  assert.equal(guestNext.ok, false);
  assert.match(guestNext.error, /ведущий/iu);
});

test("queue entries by departing listeners are dropped on leave", async () => {
  const host = await connect("host-3");
  const guest = await connect("guest-3");
  const created = await emitAck<any>(host, "room:create", { name: "Host" });
  const code = created.room.code as string;
  await emitAck<any>(guest, "room:join", { code, name: "Friend" });

  const stateAdd = new Promise<any>((resolve) => host.once("room:state", resolve));
  await emitAck<any>(guest, "room:queue-add", { code, track: roomTrack("vk:9") });
  await stateAdd;

  const stateLeave = new Promise<any>((resolve) => host.once("room:state", resolve));
  guest.disconnect();
  const state = await stateLeave;
  assert.equal(state.queue.length, 0);
  assert.equal(state.participants.length, 1);
});

const nextEvent = <T>(socket: ClientSocket, event: string) =>
  new Promise<T>((resolve) => socket.once(event, resolve));

test("private rooms require the invite; members and the owner come back", async () => {
  const host = await connect("owner-4");
  const created = await emitAck<any>(host, "room:create", { name: "Host", private: true });
  assert.equal(created.ok, true);
  assert.equal(created.room.private, true);
  const code = created.room.code as string;
  assert.equal(typeof created.invite, "string");

  const stranger = await connect("stranger-4");
  const denied = await emitAck<any>(stranger, "room:join", { code, name: "Nope" });
  assert.equal(denied.ok, false);
  assert.match(denied.error, /приглаш/iu);
  const wrong = await emitAck<any>(stranger, "room:join", { code, name: "Nope", invite: "bad" });
  assert.equal(wrong.ok, false);

  const friend = await connect("friend-4");
  const joined = await emitAck<any>(friend, "room:join", { code, name: "Friend", invite: created.invite });
  assert.equal(joined.ok, true);

  const invite = await emitAck<any>(friend, "room:invite", { code });
  assert.equal(invite.ok, false);
  const hostInvite = await emitAck<any>(host, "room:invite", { code });
  assert.equal(hostInvite.invite, created.invite);
});

test("roles: host promotes a DJ who can skip, listeners cannot", async () => {
  const host = await connect("owner-5");
  const dj = await connect("dj-5");
  const listener = await connect("listener-5");
  const code = (await emitAck<any>(host, "room:create", { name: "Host" })).room.code as string;
  const djJoin = await emitAck<any>(dj, "room:join", { code, name: "DJ" });
  await emitAck<any>(listener, "room:join", { code, name: "L" });
  const djId = djJoin.room.participants.find((p: any) => p.name === "DJ").id;
  assert.equal(djJoin.room.participants.find((p: any) => p.name === "Host").role, "host");

  const forbidden = await emitAck<any>(listener, "room:set-role", { code, participantId: djId, role: "dj" });
  assert.equal(forbidden.ok, false);
  const promoted = await emitAck<any>(host, "room:set-role", { code, participantId: djId, role: "dj" });
  assert.equal(promoted.ok, true);

  await emitAck<any>(listener, "room:queue-add", { code, track: roomTrack("vk:50") });
  const listenerNext = await emitAck<any>(listener, "room:queue-next", { code });
  assert.equal(listenerNext.ok, false);
  const state = nextEvent<any>(host, "room:state");
  const djNext = await emitAck<any>(dj, "room:queue-next", { code });
  assert.equal(djNext.ok, true);
  const after = await state;
  assert.equal(after.playback.by, dj.id);
  assert.equal(after.played.at(-1).track.id, "vk:50");
  assert.equal(after.participants.find((p: any) => p.id === djId).role, "dj");
});

test("chat is length limited and rate limited; reactions are whitelisted", async () => {
  const host = await connect("owner-6");
  const guest = await connect("guest-6");
  const code = (await emitAck<any>(host, "room:create", { name: "Host" })).room.code as string;
  await emitAck<any>(guest, "room:join", { code, name: "G" });

  const message = nextEvent<any>(host, "room:chat");
  const sent = await emitAck<any>(guest, "room:chat", { code, text: "  привет\nвсем  " });
  assert.equal(sent.ok, true);
  assert.equal((await message).text, "привет всем");
  assert.equal((await emitAck<any>(guest, "room:chat", { code, text: "x".repeat(281) })).ok, false);
  for (let i = 0; i < 4; i += 1) await emitAck<any>(guest, "room:chat", { code, text: `m${i}` });
  const limited = await emitAck<any>(guest, "room:chat", { code, text: "spam" });
  assert.equal(limited.ok, false);

  const reaction = nextEvent<any>(host, "room:reaction");
  assert.equal((await emitAck<any>(guest, "room:react", { code, emoji: "🔥" })).ok, true);
  assert.equal((await reaction).emoji, "🔥");
  assert.equal((await emitAck<any>(guest, "room:react", { code, emoji: "<b>" })).ok, false);
});

test("rooms survive a restart and keep session history", async () => {
  const host = await connect("owner-7");
  const code = (await emitAck<any>(host, "room:create", { name: "Host", private: true })).room.code as string;
  await emitAck<any>(host, "playback:update", { code, paused: false, positionMs: 0, track: roomTrack("vk:70") });
  await emitAck<any>(host, "playback:update", { code, paused: false, positionMs: 0, track: roomTrack("vk:71") });
  await emitAck<any>(host, "room:leave", {});

  resetLiveRoomsForTests();
  const back = await connect("owner-7");
  const rejoined = await emitAck<any>(back, "room:join", { code, name: "Host" });
  assert.equal(rejoined.ok, true);
  assert.equal(rejoined.room.hostId, back.id);
  assert.equal(rejoined.room.private, true);

  const history = await emitAck<any>(back, "room:history", {});
  assert.equal(history.ok, true);
  const session = history.sessions.find((item: any) => item.code === code);
  assert.deepEqual(session.tracks.map((item: any) => item.track.id), ["vk:70", "vk:71"]);
});

test("a stand-in host cannot change privacy or roles of an owned room", async () => {
  const owner = await connect("owner-9");
  const created = await emitAck<any>(owner, "room:create", { name: "Owner", private: true });
  const code = created.room.code as string;
  const friend = await connect("friend-9");
  await emitAck<any>(friend, "room:join", { code, name: "Friend", invite: created.invite });
  const other = await connect("other-9");
  const otherJoin = await emitAck<any>(other, "room:join", { code, name: "Other", invite: created.invite });
  const left = nextEvent<any>(friend, "room:state");
  owner.disconnect();
  const state = await left;
  assert.equal(state.participants.find((p: any) => p.name === "Friend").role, "host");

  const opened = await emitAck<any>(friend, "room:set-private", { code, private: false });
  assert.equal(opened.ok, false);
  const otherId = otherJoin.room.participants.find((p: any) => p.name === "Other").id;
  const promoted = await emitAck<any>(friend, "room:set-role", { code, participantId: otherId, role: "dj" });
  assert.equal(promoted.ok, false);
});
