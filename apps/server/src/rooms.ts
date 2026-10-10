import { randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import type { Server, Socket } from "socket.io";
import { RoomStore, type RoomRole } from "./room-store.js";

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
  /** Socket that made the change, so the host can apply a DJ's skip. */
  by?: string;
};

type RoomProvider = "youtube" | "yandex" | "soundcloud" | "spotify" | "vk";

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
    provider: RoomProvider;
    externalId: string;
    externalUrl: string;
    metadata: Record<string, unknown>;
  }>;
  preferredProvider?: RoomProvider;
};

type QueueEntry = {
  id: string;
  track: RoomTrack;
  addedBy: { id: string; name: string };
  votes: Set<string>;
  addedAt: number;
};

type ChatMessage = {
  id: string;
  from: { id: string; name: string };
  text: string;
  at: number;
};

type Room = {
  code: string;
  hostId: string;
  ownerUserId: string | null;
  isPrivate: boolean;
  inviteToken: string | null;
  roles: Map<string, RoomRole>;
  sessionId: string;
  participants: Map<string, Participant>;
  playback: PlaybackState;
  queue: QueueEntry[];
  played: Array<{ track: RoomTrack; playedAt: number }>;
  chat: ChatMessage[];
};

const rooms = new Map<string, Room>();
let store: RoomStore | undefined;

/** Durable storage for rooms; defaults to an in-memory database (tests). */
export function configureRoomStore(next: RoomStore) {
  store = next;
}

const roomStore = () => (store ??= new RoomStore(":memory:"));

const queueLimit = 50;
const playedLimit = 100;
const chatHistoryLimit = 50;
export const chatMessageMaxLength = 280;
export const roomReactions = ["🔥", "❤️", "👏", "😂", "😮", "🎉", "💃", "🙌"] as const;

const createCode = () => randomBytes(3).toString("hex").toUpperCase();
const createInvite = () => randomBytes(12).toString("base64url");

/** Sliding-window limiter keyed by socket id and action. */
const rateBuckets = new Map<string, number[]>();
const allowRate = (key: string, limit: number, windowMs: number) => {
  const now = Date.now();
  const hits = (rateBuckets.get(key) ?? []).filter((at) => now - at < windowMs);
  if (hits.length >= limit) {
    rateBuckets.set(key, hits);
    return false;
  }
  hits.push(now);
  rateBuckets.set(key, hits);
  return true;
};
const forgetRates = (socketId: string) => {
  for (const key of rateBuckets.keys()) if (key.startsWith(`${socketId}:`)) rateBuckets.delete(key);
};

const roleOf = (room: Room, participant: Participant | undefined): RoomRole => {
  if (!participant) return "listener";
  if (participant.id === room.hostId) return "host";
  if (participant.userId && participant.userId === room.ownerUserId) return "host";
  return (participant.userId && room.roles.get(participant.userId)) || "listener";
};

const canControl = (room: Room, socketId: string) => {
  const role = roleOf(room, room.participants.get(socketId));
  return role === "host" || role === "dj";
};

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
  private: room.isPrivate,
  participants: [...room.participants.values()].map((participant) => ({
    id: participant.id,
    name: participant.name,
    joinedAt: participant.joinedAt,
    role: roleOf(room, participant)
  })),
  playback: room.playback,
  queue: orderedQueue(room),
  played: room.played,
  chat: room.chat
});

const tokenMatches = (expected: string | null, actual: unknown) => {
  if (!expected || typeof actual !== "string") return false;
  const a = Buffer.from(expected);
  const b = Buffer.from(actual.trim().slice(0, 64));
  return a.length === b.length && timingSafeEqual(a, b);
};

const recordPlayed = (room: Room, track: RoomTrack | null) => {
  if (!track || room.played.at(-1)?.track.id === track.id) return;
  const entry = { track, playedAt: Date.now() };
  room.played = [...room.played, entry].slice(-playedLimit);
  try {
    roomStore().recordTrack(room.sessionId, track as unknown as Record<string, unknown>);
    roomStore().touch(room.code);
  } catch {
    // History is a bonus; live rooms keep working without storage.
  }
};

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

const pickHost = (room: Room) => {
  const present = [...room.participants.values()];
  const owner = present.find((p) => p.userId && p.userId === room.ownerUserId);
  const dj = present.find((p) => p.userId && room.roles.get(p.userId) === "dj");
  return (owner ?? dj ?? present[0])?.id;
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
      // The room itself stays in storage and can be reopened by its code.
      rooms.delete(code);
      try { roomStore().endSession(room.sessionId); roomStore().touch(code); } catch { /* best effort */ }
      continue;
    }
    if (room.hostId === socket.id) {
      room.hostId = pickHost(room) ?? room.hostId;
    }
    io.to(code).emit("room:state", publicRoom(room));
  }
};

const findRoomForParticipant = (socket: Socket, code: string) => {
  const room = rooms.get(code);
  if (!room || !room.participants.has(socket.id)) return undefined;
  return room;
};

const roomCode = (payload: any) =>
  typeof payload?.code === "string" ? payload.code.trim().toUpperCase().slice(0, 16) : "";

/** Brings a stored room back to life after a restart or once everyone left. */
const reviveRoom = (code: string): Room | undefined => {
  const stored = roomStore().getRoom(code);
  if (!stored) return undefined;
  const room: Room = {
    code,
    hostId: "",
    ownerUserId: stored.ownerUserId,
    isPrivate: stored.isPrivate,
    inviteToken: stored.inviteToken,
    roles: roomStore().roles(code),
    sessionId: roomStore().startSession(code),
    participants: new Map(),
    playback: { track: null, paused: true, positionMs: 0, updatedAt: Date.now(), version: 0 },
    queue: [],
    played: [],
    chat: []
  };
  rooms.set(code, room);
  return room;
};

export function registerRoomHandlers(io: Server, socket: Socket, authorize?: (create: boolean) => void) {
  const userId = () => (typeof socket.data.userId === "string" && socket.data.userId ? socket.data.userId as string : undefined);
  const newParticipant = (payload: any): Participant => ({
    id: socket.id,
    name: normalizeName(payload?.name),
    joinedAt: Date.now(),
    ...(userId() ? { userId: userId() } : {})
  });
  const remember = (room: Room) => {
    const id = userId();
    if (!id) return;
    try {
      roomStore().rememberMember(room.code, id);
      roomStore().addListener(room.sessionId, id);
    } catch { /* best effort */ }
  };

  socket.use(([event], next) => {
    if (event === "room:leave") { next(); return; }
    try { authorize?.(event === "room:create"); next(); }
    catch { socket.emit("room:access-denied", { message: "Для комнат нужен аккаунт Resonance" }); }
  });

  socket.on("room:create", (payload, acknowledge) => {
    leaveRooms(io, socket);
    let code = createCode();
    while (rooms.has(code) || roomStore().hasRoom(code)) code = createCode();

    const isPrivate = payload?.private === true;
    const inviteToken = isPrivate ? createInvite() : null;
    const now = Date.now();
    roomStore().createRoom({
      code,
      ownerUserId: userId() ?? null,
      isPrivate,
      inviteToken,
      createdAt: now,
      lastActiveAt: now
    });
    const room: Room = {
      code,
      hostId: socket.id,
      ownerUserId: userId() ?? null,
      isPrivate,
      inviteToken,
      roles: new Map(),
      sessionId: roomStore().startSession(code),
      participants: new Map([[socket.id, newParticipant(payload)]]),
      playback: { track: null, paused: true, positionMs: 0, updatedAt: now, version: 0 },
      queue: [],
      played: [],
      chat: []
    };

    rooms.set(code, room);
    remember(room);
    socket.join(code);
    acknowledge?.({ ok: true, room: publicRoom(room), ...(inviteToken ? { invite: inviteToken } : {}) });
  });

  socket.on("room:join", (payload, acknowledge) => {
    const code = roomCode(payload);
    const room = rooms.get(code) ?? (code ? reviveRoom(code) : undefined);
    if (!room) {
      acknowledge?.({ ok: false, error: "Комната не найдена" });
      return;
    }
    const id = userId();
    const known = id !== undefined && (id === room.ownerUserId || room.roles.has(id) || roomStore().isMember(code, id));
    if (room.isPrivate && !known && !tokenMatches(room.inviteToken, payload?.invite)) {
      if (room.participants.size === 0) {
        rooms.delete(code);
        roomStore().endSession(room.sessionId);
      }
      acknowledge?.({ ok: false, error: "Комната приватная — нужна ссылка-приглашение" });
      return;
    }

    leaveRooms(io, socket);
    if (!rooms.has(code)) rooms.set(code, room);

    const participant = newParticipant(payload);
    room.participants.set(socket.id, participant);
    // The owner reclaims the room; otherwise the first arrival keeps it warm.
    if (!room.participants.has(room.hostId) || (id && id === room.ownerUserId)) {
      room.hostId = socket.id;
    }
    remember(room);
    socket.join(code);
    io.to(code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true, room: publicRoom(room) });
  });

  socket.on("room:invite", (payload, acknowledge) => {
    const room = findRoomForParticipant(socket, roomCode(payload));
    if (!room) { acknowledge?.({ ok: false, error: "Комната не найдена" }); return; }
    if (!canControl(room, socket.id)) {
      acknowledge?.({ ok: false, error: "Приглашать может ведущий или диджей" });
      return;
    }
    acknowledge?.({ ok: true, private: room.isPrivate, invite: room.inviteToken });
  });

  socket.on("room:set-private", (payload, acknowledge) => {
    const room = findRoomForParticipant(socket, roomCode(payload));
    if (!room) { acknowledge?.({ ok: false, error: "Комната не найдена" }); return; }
    if (roleOf(room, room.participants.get(socket.id)) !== "host") {
      acknowledge?.({ ok: false, error: "Только ведущий меняет доступ" });
      return;
    }
    room.isPrivate = payload?.private === true;
    // Re-issuing the token revokes links that were shared before.
    room.inviteToken = room.isPrivate ? createInvite() : null;
    roomStore().setPrivacy(room.code, room.isPrivate, room.inviteToken);
    io.to(room.code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true, private: room.isPrivate, invite: room.inviteToken });
  });

  socket.on("room:set-role", (payload, acknowledge) => {
    const room = findRoomForParticipant(socket, roomCode(payload));
    if (!room) { acknowledge?.({ ok: false, error: "Комната не найдена" }); return; }
    if (roleOf(room, room.participants.get(socket.id)) !== "host") {
      acknowledge?.({ ok: false, error: "Роли назначает только ведущий" });
      return;
    }
    const role = payload?.role === "dj" ? "dj" : payload?.role === "listener" ? "listener" : undefined;
    const target = room.participants.get(typeof payload?.participantId === "string" ? payload.participantId : "");
    if (!role || !target) { acknowledge?.({ ok: false, error: "Участник не найден" }); return; }
    if (!target.userId || target.userId === room.ownerUserId || target.id === room.hostId) {
      acknowledge?.({ ok: false, error: "Роль этого участника нельзя изменить" });
      return;
    }
    room.roles.set(target.userId, role);
    roomStore().setRole(room.code, target.userId, role);
    io.to(room.code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true });
  });

  socket.on("playback:update", (payload, acknowledge) => {
    const code = roomCode(payload);
    const room = rooms.get(code);
    if (!room) {
      acknowledge?.({ ok: false, error: "Комната не найдена" });
      return;
    }
    if (!room.participants.has(socket.id) || !canControl(room, socket.id)) {
      acknowledge?.({ ok: false, error: "Только ведущий или диджей управляет комнатой" });
      return;
    }

    const track = normalizeTrack(payload.track);
    room.playback = {
      track,
      paused: payload.paused !== false,
      positionMs:
        typeof payload.positionMs === "number"
          ? Math.max(0, Math.floor(payload.positionMs))
          : 0,
      updatedAt: Date.now(),
      version: room.playback.version + 1,
      by: socket.id
    };
    recordPlayed(room, track);

    io.to(code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true });
  });

  socket.on("room:queue-add", (payload, acknowledge) => {
    const code = roomCode(payload);
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
    const code = roomCode(payload);
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
    const code = roomCode(payload);
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
    if (!canControl(room, socket.id) && entry.addedBy.id !== socket.id) {
      acknowledge?.({ ok: false, error: "Удалять может ведущий, диджей или добавивший" });
      return;
    }
    room.queue.splice(index, 1);
    io.to(code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true });
  });

  socket.on("room:queue-next", (payload, acknowledge) => {
    const code = roomCode(payload);
    const room = findRoomForParticipant(socket, code);
    if (!room) {
      acknowledge?.({ ok: false, error: "Комната не найдена" });
      return;
    }
    if (!canControl(room, socket.id)) {
      acknowledge?.({ ok: false, error: "Только ведущий или диджей управляет комнатой" });
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
      version: room.playback.version + 1,
      by: socket.id
    };
    recordPlayed(room, next.track);
    io.to(code).emit("room:state", publicRoom(room));
    acknowledge?.({ ok: true, trackId: next.track.id });
  });

  socket.on("room:chat", (payload, acknowledge) => {
    const room = findRoomForParticipant(socket, roomCode(payload));
    if (!room) { acknowledge?.({ ok: false, error: "Комната не найдена" }); return; }
    const raw = typeof payload?.text === "string" ? payload.text : "";
    // Plain text only: control characters are stripped, whitespace collapsed.
    const text = raw.replace(/[\u0000-\u001f\u007f]/gu, " ").replace(/\s+/gu, " ").trim();
    if (!text) { acknowledge?.({ ok: false, error: "Пустое сообщение" }); return; }
    if ([...text].length > chatMessageMaxLength) {
      acknowledge?.({ ok: false, error: `Не длиннее ${chatMessageMaxLength} символов` });
      return;
    }
    if (!allowRate(`${socket.id}:chat`, 5, 10_000)) {
      acknowledge?.({ ok: false, error: "Слишком часто — подождите пару секунд" });
      return;
    }
    const participant = room.participants.get(socket.id)!;
    const message: ChatMessage = {
      id: randomUUID(),
      from: { id: socket.id, name: participant.name },
      text,
      at: Date.now()
    };
    room.chat = [...room.chat, message].slice(-chatHistoryLimit);
    io.to(room.code).emit("room:chat", message);
    acknowledge?.({ ok: true });
  });

  socket.on("room:react", (payload, acknowledge) => {
    const room = findRoomForParticipant(socket, roomCode(payload));
    if (!room) { acknowledge?.({ ok: false, error: "Комната не найдена" }); return; }
    const emoji = typeof payload?.emoji === "string" ? payload.emoji : "";
    if (!(roomReactions as readonly string[]).includes(emoji)) {
      acknowledge?.({ ok: false, error: "Такой реакции нет" });
      return;
    }
    if (!allowRate(`${socket.id}:react`, 8, 5_000)) {
      acknowledge?.({ ok: false, error: "Слишком много реакций" });
      return;
    }
    const participant = room.participants.get(socket.id)!;
    io.to(room.code).emit("room:reaction", {
      id: randomUUID(),
      emoji,
      from: { id: socket.id, name: participant.name },
      at: Date.now()
    });
    acknowledge?.({ ok: true });
  });

  socket.on("room:history", (_payload, acknowledge) => {
    const id = userId();
    if (!id) { acknowledge?.({ ok: true, sessions: [] }); return; }
    try {
      acknowledge?.({ ok: true, sessions: roomStore().history(id) });
    } catch {
      acknowledge?.({ ok: false, error: "История недоступна" });
    }
  });

  socket.on("room:leave", (_payload, acknowledge) => {
    leaveRooms(io, socket);
    acknowledge?.({ ok: true });
  });

  socket.on("disconnect", () => {
    leaveRooms(io, socket);
    forgetRates(socket.id);
  });
}

/** Aggregate counts only: room codes are private invitations and never listed. */
export function roomStats() {
  let participants = 0;
  for (const room of rooms.values()) participants += room.participants.size;
  return { rooms: rooms.size, participants };
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

/** Test hook: drops live rooms as if the server process restarted. */
export function resetLiveRoomsForTests() {
  rooms.clear();
  rateBuckets.clear();
}
