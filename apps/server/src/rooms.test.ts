import assert from "node:assert/strict";
import { createServer } from "node:http";
import { after, before, test } from "node:test";
import { io as createClient, type Socket as ClientSocket } from "socket.io-client";
import { Server } from "socket.io";
import { registerRoomHandlers } from "./rooms.js";

let io: Server;
let url: string;
const clients: ClientSocket[] = [];

before(async () => {
  const http = createServer();
  io = new Server(http);
  io.on("connection", (socket) => registerRoomHandlers(io, socket));
  await new Promise<void>((resolve) => http.listen(0, "127.0.0.1", resolve));
  const address = http.address();
  assert(address && typeof address === "object");
  url = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  for (const client of clients) client.disconnect();
  await io.close();
});

const connect = async () => {
  const client = createClient(url, { transports: ["websocket"] });
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
  const host = await connect();
  const guest = await connect();
  const created = await emitAck<any>(host, "room:create", { name: "Host" });
  assert.equal(created.ok, true);
  const code = created.room.code as string;

  const joined = await emitAck<any>(guest, "room:join", { code, name: "Friend" });
  assert.equal(joined.ok, true);
  assert.equal(joined.room.participants.length, 2);

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
