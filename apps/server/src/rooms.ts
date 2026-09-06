import { randomBytes, randomUUID } from "node:crypto";
import type { Server, Socket } from "socket.io";

type Participant = {
  id: string;
  name: string;
  joinedAt: number;
  userId?: string;
};

type PlaybackState = {
  track: RoomTrack | null;
  paused: boolean;
  positionMs: number;
  updatedAt: number;
  version: number;
};

type RoomTrack = {
  id: string;
  title: string;
  normalizedTitle: string;
  artist: string;
  normalizedArtist: string;
  album?: string;
  duration?: number;
  artworkUrl?: string;
  sources: Array<{
    provider: "youtube" | "yandex" | "soundcloud";
    externalId: string;
    externalUrl: string;
    metadata: Record<string, unknown>;
  }>;
  preferredProvider?: "youtube" | "yandex" | "soundcloud";
};

type QueueEntry = {
  id: string;
  track: RoomTrack;
  addedBy: { id: string; name: string };
  votes: Set<string>;
  addedAt: number;
};

type Room = {
  code: string;
  hostId: string;
  participants: Map<string, Participant>;
  playback: PlaybackState;
  queue: QueueEntry[];
};

const rooms = new Map<string, Room>();

const queueLimit = 50;

const createCode = () => randomBytes(3).toString("hex").toUpperCase();

const publicQueueEntry = (entry: QueueEntry) => ({
  id: entry.id,
  track: entry.track,
  addedBy: entry.addedBy,
  votes: entry.votes.size,
  voters: [...entry.votes],
  addedAt: entry.addedAt
});

const orderedQueue = (room: Room) =>
  [...room.queue]
    .sort((a, b) => b.votes.size - a.votes.size || a.addedAt - b.addedAt)
    .map(publicQueueEntry);

const publicRoom = (room: Room) => ({
  code: room.code,
  hostId: room.hostId,
  participants: [...room.participants.values()].map(({ id, name, joinedAt }) => ({ id, name, joinedAt })),
  playback: room.playback,
  queue: orderedQueue(room)
});

const normalizeName = (value: unknown) => {
  if (typeof value !== "string") return "Слушатель";
  return value.trim().slice(0, 32) || "Слушатель";
};

const providers = new Set(["youtube", "yandex", "soundcloud", "spotify", "vk"]);
const shortString = (value: unknown, length = 256) =>
  typeof value === "string" ? value.trim().slice(0, length) : "";

const normalizeTrack = (value: unknown): RoomTrack | null => {
  if (!value || typeof value !== "object") return null;
  const input = value as Record<string, unknown>;
  const id = shortString(input.id, 160);
  const title = shortString(input.title);
  const artist = shortString(input.artist);
  if (!id || !title || !artist || !Array.isArray(input.sources)) return null;

  const sources = input.sources.flatMap((raw) => {
    if (!raw || typeof raw !== "object") return [];
    const source = raw as Record<string, unknown>;
    const provider = shortString(source.provider, 20);
    const externalId = shortString(source.externalId, 256);
    const externalUrl = shortString(source.externalUrl, 2048);
    if (!providers.has(provider) || !externalId || !externalUrl) return [];
    try {
      const parsed = new URL(externalUrl);
      if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return [];
    } catch {
      return [];
    }
    return [{
      provider: provider as RoomTrack["sources"][number]["provider"],
      externalId,
      externalUrl,
      // Provider resolvers only need non-sensitive catalog metadata here.
      metadata: {}
    }];
  }).slice(0, 6);
  if (sources.length === 0) return null;

  const preferred = shortString(input.preferredProvider, 20);
  return {
    id,
    title,
    normalizedTitle: shortString(input.normalizedTitle) || title.toLowerCase(),
    artist,
    normalizedArtist: shortString(input.normalizedArtist) || artist.toLowerCase(),
    ...(shortString(input.album) ? { album: shortString(input.album) } : {}),
    ...(typeof input.duration === "number" && Number.isFinite(input.duration)
      ? { duration: Math.max(0, Math.floor(input.duration)) }
      : {}),
    ...(shortString(input.artworkUrl, 2048)
      ? { artworkUrl: shortString(input.artworkUrl, 2048) }
      : {}),
    sources,
    ...(providers.has(preferred)
      ? { preferredProvider: preferred as RoomTrack["sources"][number]["provider"] }
      : {})
  };
};

const leaveRooms = (io: Server, socket: Socket) => {
  for (const [code, room] of rooms) {
    if (!room.participants.delete(socket.id)) continue;
    // Drop the departing listener's votes and their queue entries.
    room.queue = room.queue.filter((entry) => {
      entry.votes.delete(socket.id);
      return entry.addedBy.id !== socket.id || entry.votes.size > 0;
    });
    socket.leave(code);
    if (room.participants.size === 0) {
      rooms.delete(code);
      continue;
    }
    if (room.hostId === socket.id) {
      room.hostId = room.participants.keys().next().value as string;
    }
    io.to(code).emit("room:state", publicRoom(room));
  }
};

const findRoomForParticipant = (socket: Socket, code: string) => {
  const room = rooms.get(code);
  if (!room || !room.participants.has(socket.id)) return undefined;
  return room;
};

export function registerRoomHandlers(io: Server, socket: Socket, authorize?: (create: boolean) => void) {
  socket.use(([event], next) => {
    if (event === "room:leave") { next(); return; }
    try { authorize?.(event === "room:create"); next(); }
    catch { socket.emit("room:access-denied", { message: "Для этой функции нужна подписка Plus или Family" }); }
  });
  socket.on("room:create", (payload, acknowledge) => {
    leaveRooms(io, socket);
    let code = createCode();
    while (rooms.has(code)) code = createCode();

    const participant: Participant = {
      id: socket.id,
      name: normalizeName(payload?.name),
      joinedAt: Date.now(),
      ...(typeof socket.data.userId === "string" ? { userId: socket.data.userId } : {})
    };
    const room: Room = {
      code,
      hostId: socket.id,
      participants: new Map([[socket.id, participant]]),
      playback: {
        track: null,
        paused: true,
        positionMs: 0,
        updatedAt: Date.now(),
        version: 0
      },
      queue: []
    };

    rooms.set(code, room);
    socket.join(code);
    acknowledge?.({ ok: true, room: publicRoom(room) });
  });

  socket.on("room:join", (payload, acknowledge) => {
    const code =
      typeof payload?.code === "string" ? payload.code.trim().toUpperCase() : "";
    const room = rooms.get(code);
    if (!room) {
      acknowledge?.({ ok: false, error: "Комната не найдена" });
      return;
    }

    leaveRooms(io, socket);

    const participant: Participant = {
      id: socket.id,
      name: normalizeName(payload?.name),
      joinedAt: Date.now(),
      ...(typeof socket.data.userId === "string" ? { userId: socket.data.userId } : {})
    };
    room.participants.set(socket.id, participant);
    socket.join(code);
    io.to(code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true, room: publicRoom(room) });
  });

  socket.on("playback:update", (payload, acknowledge) => {
    const code =
      typeof payload?.code === "string" ? payload.code.trim().toUpperCase() : "";
    const room = rooms.get(code);
    if (!room) {
      acknowledge?.({ ok: false, error: "Комната не найдена" });
      return;
    }
    if (room.hostId !== socket.id) {
      acknowledge?.({ ok: false, error: "Только ведущий управляет комнатой" });
      return;
    }

    room.playback = {
      track: normalizeTrack(payload.track),
      paused: payload.paused !== false,
      positionMs:
        typeof payload.positionMs === "number"
          ? Math.max(0, Math.floor(payload.positionMs))
          : 0,
      updatedAt: Date.now(),
      version: room.playback.version + 1
    };

    io.to(code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true });
  });

  socket.on("room:queue-add", (payload, acknowledge) => {
    const code =
      typeof payload?.code === "string" ? payload.code.trim().toUpperCase() : "";
    const room = findRoomForParticipant(socket, code);
    if (!room) {
      acknowledge?.({ ok: false, error: "Комната не найдена" });
      return;
    }
    const track = normalizeTrack(payload?.track);
    if (!track) {
      acknowledge?.({ ok: false, error: "Некорректный трек" });
      return;
    }
    if (room.queue.some((entry) => entry.track.id === track.id)) {
      acknowledge?.({ ok: false, error: "Трек уже в очереди" });
      return;
    }
    if (room.queue.length >= queueLimit) {
      acknowledge?.({ ok: false, error: "Очередь переполнена" });
      return;
    }
    const participant = room.participants.get(socket.id)!;
    room.queue.push({
      id: randomUUID(),
      track,
      addedBy: { id: socket.id, name: participant.name },
      votes: new Set([socket.id]),
      addedAt: Date.now()
    });
    io.to(code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true });
  });

  socket.on("room:queue-vote", (payload, acknowledge) => {
    const code =
      typeof payload?.code === "string" ? payload.code.trim().toUpperCase() : "";
    const entryId = typeof payload?.entryId === "string" ? payload.entryId.trim().slice(0, 64) : "";
    const room = findRoomForParticipant(socket, code);
    const entry = room?.queue.find((item) => item.id === entryId);
    if (!room || !entry) {
      acknowledge?.({ ok: false, error: "Трек очереди не найден" });
      return;
    }
    if (!entry.votes.delete(socket.id)) {
      if (entry.addedBy.id !== socket.id) entry.votes.add(socket.id);
    }
    io.to(code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true });
  });

  socket.on("room:queue-remove", (payload, acknowledge) => {
    const code =
      typeof payload?.code === "string" ? payload.code.trim().toUpperCase() : "";
    const entryId = typeof payload?.entryId === "string" ? payload.entryId.trim().slice(0, 64) : "";
    const room = findRoomForParticipant(socket, code);
    if (!room) {
      acknowledge?.({ ok: false, error: "Комната не найдена" });
      return;
    }
    const index = room.queue.findIndex((item) => item.id === entryId);
    if (index < 0) {
      acknowledge?.({ ok: false, error: "Трек очереди не найден" });
      return;
    }
    const entry = room.queue[index]!;
    if (room.hostId !== socket.id && entry.addedBy.id !== socket.id) {
      acknowledge?.({ ok: false, error: "Удалять может ведущий или добавивший" });
      return;
    }
    room.queue.splice(index, 1);
    io.to(code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true });
  });

  socket.on("room:queue-next", (payload, acknowledge) => {
    const code =
      typeof payload?.code === "string" ? payload.code.trim().toUpperCase() : "";
    const room = findRoomForParticipant(socket, code);
    if (!room) {
      acknowledge?.({ ok: false, error: "Комната не найдена" });
      return;
    }
    if (room.hostId !== socket.id) {
      acknowledge?.({ ok: false, error: "Только ведущий управляет комнатой" });
      return;
    }
    const [next] = [...room.queue].sort(
      (a, b) => b.votes.size - a.votes.size || a.addedAt - b.addedAt
    );
    if (!next) {
      acknowledge?.({ ok: false, error: "Очередь пуста" });
      return;
    }
    room.queue = room.queue.filter((entry) => entry.id !== next.id);
    room.playback = {
      track: next.track,
      paused: false,
      positionMs: 0,
      updatedAt: Date.now(),
      version: room.playback.version + 1
    };
    io.to(code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true, trackId: next.track.id });
  });

  socket.on("room:leave", (_payload, acknowledge) => {
    leaveRooms(io, socket);
    acknowledge?.({ ok: true });
  });

  socket.on("disconnect", () => {
    leaveRooms(io, socket);
  });
}

export function roomWaveUserIds(code: string, hostUserId: string) {
  const room = rooms.get(code.trim().toUpperCase());
  const host = room?.participants.get(room.hostId);
  if (!room || host?.userId !== hostUserId) return [];
  return [...new Set(
    [...room.participants.values()]
      .map((participant) => participant.userId)
      .filter((value): value is string => typeof value === "string" && value.length > 0)
  )].slice(0, 10);
}
