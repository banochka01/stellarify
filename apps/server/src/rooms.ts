import { randomBytes } from "node:crypto";
import type { Server, Socket } from "socket.io";

type Participant = {
  id: string;
  name: string;
  joinedAt: number;
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

type Room = {
  code: string;
  hostId: string;
  participants: Map<string, Participant>;
  playback: PlaybackState;
};

const rooms = new Map<string, Room>();

const createCode = () => randomBytes(3).toString("hex").toUpperCase();

const publicRoom = (room: Room) => ({
  code: room.code,
  hostId: room.hostId,
  participants: [...room.participants.values()],
  playback: room.playback
});

const normalizeName = (value: unknown) => {
  if (typeof value !== "string") return "Слушатель";
  return value.trim().slice(0, 32) || "Слушатель";
};

const providers = new Set(["youtube", "yandex", "soundcloud"]);
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
      joinedAt: Date.now()
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
      }
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
      joinedAt: Date.now()
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

  socket.on("room:leave", (_payload, acknowledge) => {
    leaveRooms(io, socket);
    acknowledge?.({ ok: true });
  });

  socket.on("disconnect", () => {
    leaveRooms(io, socket);
  });
}
