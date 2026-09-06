import assert from "node:assert/strict";
import { createServer } from "node:http";
import { after, before, test } from "node:test";
import { io as createClient, type Socket as ClientSocket } from "socket.io-client";
import { Server } from "socket.io";
import { registerRoomHandlers, roomWaveUserIds } from "./rooms.js";

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
