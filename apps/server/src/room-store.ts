import { randomUUID } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

export type RoomRole = "host" | "dj" | "listener";

export type StoredRoom = {
  code: string;
  ownerUserId: string | null;
  isPrivate: boolean;
  inviteToken: string | null;
  createdAt: number;
  lastActiveAt: number;
};

export type RoomSessionSummary = {
  id: string;
  code: string;
  startedAt: number;
  endedAt: number | null;
  tracks: Array<{ track: Record<string, unknown>; playedAt: number }>;
};

const roomLifetimeMs = 30 * 24 * 60 * 60 * 1_000;
const historyTrackLimit = 200;

/**
 * Durable rooms: metadata, roles by Resonance account and session history.
 * Live presence (sockets, queue, chat) stays in memory; this store lets a
 * room and its host survive a server restart and powers «Переслушать».
 */
export class RoomStore {
  readonly #database: DatabaseSync;

  constructor(path: string) {
    if (path !== ":memory:") mkdirSync(dirname(path), { recursive: true });
    this.#database = new DatabaseSync(path);
    this.#database.exec("PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;");
    if (path !== ":memory:") this.#database.exec("PRAGMA journal_mode = WAL;");
    this.#database.exec(`
      CREATE TABLE IF NOT EXISTS rooms (
        code TEXT PRIMARY KEY,
        owner_user_id TEXT,
        is_private INTEGER NOT NULL DEFAULT 0,
        invite_token TEXT,
        created_at INTEGER NOT NULL,
        last_active_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS room_members (
        code TEXT NOT NULL REFERENCES rooms(code) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        last_seen_at INTEGER NOT NULL,
        PRIMARY KEY (code, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_room_members_user ON room_members(user_id);
      CREATE TABLE IF NOT EXISTS room_sessions (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL REFERENCES rooms(code) ON DELETE CASCADE,
        started_at INTEGER NOT NULL,
        ended_at INTEGER
      );
      CREATE INDEX IF NOT EXISTS idx_room_sessions_code ON room_sessions(code, started_at);
      CREATE TABLE IF NOT EXISTS room_session_tracks (
        session_id TEXT NOT NULL REFERENCES room_sessions(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        track_json TEXT NOT NULL,
        played_at INTEGER NOT NULL,
        PRIMARY KEY (session_id, position)
      );
      CREATE TABLE IF NOT EXISTS room_session_listeners (
        session_id TEXT NOT NULL REFERENCES room_sessions(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        PRIMARY KEY (session_id, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_room_session_listeners_user ON room_session_listeners(user_id);
    `);
    const now = Date.now();
    this.#database.prepare("DELETE FROM rooms WHERE last_active_at < ?").run(now - roomLifetimeMs);
    // Sessions left open by a crash or restart are closed at restart time.
    this.#database.prepare("UPDATE room_sessions SET ended_at = ? WHERE ended_at IS NULL").run(now);
  }

  createRoom(room: StoredRoom) {
    this.#database.prepare(`
      INSERT INTO rooms (code, owner_user_id, is_private, invite_token, created_at, last_active_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(room.code, room.ownerUserId, room.isPrivate ? 1 : 0, room.inviteToken, room.createdAt, room.lastActiveAt);
  }

  getRoom(code: string): StoredRoom | undefined {
    const row = this.#database.prepare("SELECT * FROM rooms WHERE code = ?").get(code) as
      | Record<string, unknown>
      | undefined;
    if (!row) return undefined;
    return {
      code: String(row.code),
      ownerUserId: typeof row.owner_user_id === "string" ? row.owner_user_id : null,
      isPrivate: Number(row.is_private) === 1,
      inviteToken: typeof row.invite_token === "string" ? row.invite_token : null,
      createdAt: Number(row.created_at),
      lastActiveAt: Number(row.last_active_at)
    };
  }

  hasRoom(code: string) {
    return this.#database.prepare("SELECT 1 FROM rooms WHERE code = ?").get(code) !== undefined;
  }

  setPrivacy(code: string, isPrivate: boolean, inviteToken: string | null) {
    this.#database.prepare("UPDATE rooms SET is_private = ?, invite_token = ? WHERE code = ?")
      .run(isPrivate ? 1 : 0, inviteToken, code);
  }

  touch(code: string) {
    this.#database.prepare("UPDATE rooms SET last_active_at = ? WHERE code = ?").run(Date.now(), code);
  }

  roles(code: string): Map<string, RoomRole> {
    const rows = this.#database.prepare("SELECT user_id, role FROM room_members WHERE code = ?").all(code) as Array<
      Record<string, unknown>
    >;
    return new Map(rows.map((row) => [String(row.user_id), row.role === "dj" ? "dj" : "listener"]));
  }

  isMember(code: string, userId: string) {
    return this.#database.prepare("SELECT 1 FROM room_members WHERE code = ? AND user_id = ?").get(code, userId) !== undefined;
  }

  rememberMember(code: string, userId: string) {
    this.#database.prepare(`
      INSERT INTO room_members (code, user_id, role, last_seen_at) VALUES (?, ?, 'listener', ?)
      ON CONFLICT(code, user_id) DO UPDATE SET last_seen_at = excluded.last_seen_at
    `).run(code, userId, Date.now());
  }

  setRole(code: string, userId: string, role: Exclude<RoomRole, "host">) {
    this.#database.prepare(`
      INSERT INTO room_members (code, user_id, role, last_seen_at) VALUES (?, ?, ?, ?)
      ON CONFLICT(code, user_id) DO UPDATE SET role = excluded.role
    `).run(code, userId, role, Date.now());
  }

  startSession(code: string) {
    const id = randomUUID();
    this.#database.prepare("INSERT INTO room_sessions (id, code, started_at) VALUES (?, ?, ?)").run(id, code, Date.now());
    return id;
  }

  endSession(sessionId: string) {
    this.#database.prepare("UPDATE room_sessions SET ended_at = ? WHERE id = ? AND ended_at IS NULL")
      .run(Date.now(), sessionId);
  }

  addListener(sessionId: string, userId: string) {
    this.#database.prepare("INSERT OR IGNORE INTO room_session_listeners (session_id, user_id) VALUES (?, ?)")
      .run(sessionId, userId);
  }

  recordTrack(sessionId: string, track: Record<string, unknown>) {
    const row = this.#database.prepare(
      "SELECT COUNT(*) AS count FROM room_session_tracks WHERE session_id = ?"
    ).get(sessionId) as { count: number };
    if (Number(row.count) >= historyTrackLimit) return;
    this.#database.prepare(`
      INSERT INTO room_session_tracks (session_id, position, track_json, played_at) VALUES (?, ?, ?, ?)
    `).run(sessionId, Number(row.count), JSON.stringify(track), Date.now());
  }

  /** Recent sessions the user took part in, newest first, with played tracks. */
  history(userId: string, limit = 20): RoomSessionSummary[] {
    const sessions = this.#database.prepare(`
      SELECT s.id, s.code, s.started_at, s.ended_at FROM room_sessions s
      JOIN room_session_listeners l ON l.session_id = s.id
      WHERE l.user_id = ?
        AND EXISTS (SELECT 1 FROM room_session_tracks t WHERE t.session_id = s.id)
      ORDER BY s.started_at DESC LIMIT ?
    `).all(userId, Math.max(1, Math.min(50, limit))) as Array<Record<string, unknown>>;
    return sessions.map((session) => ({
      id: String(session.id),
      code: String(session.code),
      startedAt: Number(session.started_at),
      endedAt: session.ended_at == null ? null : Number(session.ended_at),
      tracks: this.sessionTracks(String(session.id))
    }));
  }

  sessionTracks(sessionId: string) {
    return (this.#database.prepare(
      "SELECT track_json, played_at FROM room_session_tracks WHERE session_id = ? ORDER BY position"
    ).all(sessionId) as Array<Record<string, unknown>>).flatMap((row) => {
      try {
        return [{ track: JSON.parse(String(row.track_json)) as Record<string, unknown>, playedAt: Number(row.played_at) }];
      } catch {
        return [];
      }
    });
  }

  close() {
    this.#database.close();
  }
}
