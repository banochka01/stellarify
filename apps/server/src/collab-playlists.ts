import { randomUUID } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import express from "express";
import { z } from "zod";
import { ApiError, handle, parse, RateGate, requireUser, transaction, type Authenticate } from "./api-helpers.js";

export type CollabRole = "owner" | "editor" | "viewer";

export type CollabHistoryEntry = {
  id: number;
  userId: string;
  action: "add" | "remove" | "rename";
  entryId: string | null;
  track: Record<string, unknown> | null;
  position: number | null;
  oldName: string | null;
  newName: string | null;
  revertOf: number | null;
  revertedBy: number | null;
  createdAt: string;
};

const MAX_TRACKS = 2_000;
const MAX_MEMBERS = 50;
const MAX_HISTORY = 1_000;

/**
 * Collaborative playlists: owner + members with roles, a full edit history
 * (who added/removed/renamed what) and one-step revert of any history entry.
 */
export class CollabPlaylistStore {
  constructor(
    private readonly db: DatabaseSync,
    private readonly now: () => number = Date.now,
    /** Blocked accounts lose access to each other's playlists. */
    private readonly isBlocked: (a: string, b: string) => boolean = () => false,
    private readonly maxTracks = MAX_TRACKS
  ) {
    db.exec(`
      CREATE TABLE IF NOT EXISTS collab_playlists (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        version INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS collab_members (
        playlist_id TEXT NOT NULL REFERENCES collab_playlists(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_collab_members_user ON collab_members(user_id);
      CREATE TABLE IF NOT EXISTS collab_tracks (
        playlist_id TEXT NOT NULL REFERENCES collab_playlists(id) ON DELETE CASCADE,
        entry_id TEXT NOT NULL,
        track_json TEXT NOT NULL,
        position REAL NOT NULL,
        added_by TEXT NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, entry_id)
      );
      CREATE TABLE IF NOT EXISTS collab_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id TEXT NOT NULL REFERENCES collab_playlists(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        entry_id TEXT,
        track_json TEXT,
        position REAL,
        old_name TEXT,
        new_name TEXT,
        revert_of INTEGER,
        reverted_by INTEGER,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_collab_history_playlist ON collab_history(playlist_id, id DESC);
    `);
  }

  create(ownerId: string, name: string) {
    const owned = this.db.prepare("SELECT COUNT(*) AS count FROM collab_playlists WHERE owner_id = ?").get(ownerId) as { count: number };
    if (Number(owned.count) >= 100) throw new ApiError("COLLAB_LIMIT", "Достигнут лимит совместных плейлистов", 409);
    const id = randomUUID();
    const now = this.now();
    this.db.prepare("INSERT INTO collab_playlists (id, owner_id, name, created_at, updated_at) VALUES (?, ?, ?, ?, ?)")
      .run(id, ownerId, name, now, now);
    return this.get(id, ownerId);
  }

  /** Unfriend/block: drop each side from the other's playlists. */
  removeSharedMemberships(a: string, b: string) {
    this.db.prepare(`
      DELETE FROM collab_members WHERE
        (user_id = ? AND playlist_id IN (SELECT id FROM collab_playlists WHERE owner_id = ?)) OR
        (user_id = ? AND playlist_id IN (SELECT id FROM collab_playlists WHERE owner_id = ?))
    `).run(b, a, a, b);
  }

  role(playlistId: string, userId: string): CollabRole | undefined {
    const playlist = this.db.prepare("SELECT owner_id FROM collab_playlists WHERE id = ?").get(playlistId) as { owner_id: string } | undefined;
    if (!playlist) return undefined;
    if (playlist.owner_id === userId) return "owner";
    if (this.isBlocked(playlist.owner_id, userId)) return undefined;
    const member = this.db.prepare("SELECT role FROM collab_members WHERE playlist_id = ? AND user_id = ?").get(playlistId, userId) as { role: string } | undefined;
    return member ? (member.role === "editor" ? "editor" : "viewer") : undefined;
  }

  #require(playlistId: string, userId: string, needed: CollabRole) {
    const role = this.role(playlistId, userId);
    // Non-members get 404 so playlist ids cannot be probed.
    if (!role) throw new ApiError("PLAYLIST_NOT_FOUND", "Плейлист не найден", 404);
    const rank = { viewer: 0, editor: 1, owner: 2 };
    if (rank[role] < rank[needed]) throw new ApiError("FORBIDDEN", needed === "owner" ? "Только владелец может это сделать" : "Нужны права редактора", 403);
    return role;
  }

  list(userId: string) {
    return (this.db.prepare(`
      SELECT p.id, p.name, p.owner_id, p.updated_at,
        CASE WHEN p.owner_id = ? THEN 'owner'
          ELSE (SELECT m.role FROM collab_members m WHERE m.playlist_id = p.id AND m.user_id = ?) END AS role,
        (SELECT COUNT(*) FROM collab_tracks t WHERE t.playlist_id = p.id) AS track_count,
        (SELECT COUNT(*) FROM collab_members m WHERE m.playlist_id = p.id) AS member_count
      FROM collab_playlists p
      WHERE p.owner_id = ? OR p.id IN (SELECT playlist_id FROM collab_members WHERE user_id = ?)
      ORDER BY p.updated_at DESC
    `).all(userId, userId, userId, userId) as Array<{ id: string; name: string; owner_id: string; role: string; updated_at: number; track_count: number; member_count: number }>)
      .filter((row) => row.role === "owner" || !this.isBlocked(row.owner_id, userId))
      .map((row) => ({
        id: row.id,
        name: row.name,
        ownerId: row.owner_id,
        role: (row.role === "owner" ? "owner" : row.role === "editor" ? "editor" : "viewer") as CollabRole,
        trackCount: Number(row.track_count),
        memberCount: Number(row.member_count) + 1,
        updatedAt: new Date(row.updated_at).toISOString()
      }));
  }

  get(playlistId: string, userId: string) {
    const role = this.#require(playlistId, userId, "viewer");
    const row = this.db.prepare("SELECT * FROM collab_playlists WHERE id = ?").get(playlistId) as {
      id: string; owner_id: string; name: string; created_at: number; updated_at: number; version: number;
    };
    const members = (this.db.prepare("SELECT user_id, role, added_at FROM collab_members WHERE playlist_id = ? ORDER BY added_at").all(playlistId) as Array<{ user_id: string; role: string; added_at: number }>)
      .map((member) => ({ userId: member.user_id, role: member.role as CollabRole, addedAt: new Date(member.added_at).toISOString() }));
    const tracks = (this.db.prepare("SELECT * FROM collab_tracks WHERE playlist_id = ? ORDER BY position, added_at").all(playlistId) as TrackRow[])
      .map(toEntry);
    return {
      id: row.id,
      name: row.name,
      ownerId: row.owner_id,
      role,
      version: Number(row.version),
      createdAt: new Date(row.created_at).toISOString(),
      updatedAt: new Date(row.updated_at).toISOString(),
      members: [{ userId: row.owner_id, role: "owner" as CollabRole, addedAt: new Date(row.created_at).toISOString() }, ...members],
      tracks
    };
  }

  delete(playlistId: string, userId: string) {
    this.#require(playlistId, userId, "owner");
    this.db.prepare("DELETE FROM collab_playlists WHERE id = ?").run(playlistId);
  }

  setMember(playlistId: string, ownerId: string, memberId: string, role: Exclude<CollabRole, "owner">) {
    this.#require(playlistId, ownerId, "owner");
    if (memberId === ownerId) throw new ApiError("INVALID_REQUEST", "Владелец уже в плейлисте", 400);
    const count = this.db.prepare("SELECT COUNT(*) AS count FROM collab_members WHERE playlist_id = ?").get(playlistId) as { count: number };
    const existing = this.role(playlistId, memberId);
    if (!existing && Number(count.count) >= MAX_MEMBERS) throw new ApiError("COLLAB_LIMIT", "Слишком много участников", 409);
    this.db.prepare(`
      INSERT INTO collab_members (playlist_id, user_id, role, added_at) VALUES (?, ?, ?, ?)
      ON CONFLICT(playlist_id, user_id) DO UPDATE SET role = excluded.role
    `).run(playlistId, memberId, role, this.now());
    this.#touch(playlistId);
    return this.get(playlistId, ownerId);
  }

  /** The owner removes anyone; a member may remove only themselves (leave). */
  removeMember(playlistId: string, userId: string, memberId: string) {
    if (userId !== memberId) this.#require(playlistId, userId, "owner");
    else this.#require(playlistId, userId, "viewer");
    this.db.prepare("DELETE FROM collab_members WHERE playlist_id = ? AND user_id = ?").run(playlistId, memberId);
    this.#touch(playlistId);
  }

  addTrack(playlistId: string, userId: string, track: Record<string, unknown>, position?: number) {
    this.#require(playlistId, userId, "editor");
    return transaction(this.db, () => {
      const count = this.db.prepare("SELECT COUNT(*) AS count, MAX(position) AS last FROM collab_tracks WHERE playlist_id = ?").get(playlistId) as { count: number; last: number | null };
      if (Number(count.count) >= this.maxTracks) throw new ApiError("COLLAB_LIMIT", "В плейлисте слишком много треков", 409);
      const entryId = randomUUID();
      const at = position ?? (count.last === null ? 0 : Number(count.last) + 1);
      this.#insertTrack(playlistId, entryId, track, at, userId);
      this.#history(playlistId, userId, { action: "add", entryId, track, position: at });
      this.#touch(playlistId);
      return this.#entry(playlistId, entryId)!;
    });
  }

  removeTrack(playlistId: string, userId: string, entryId: string) {
    this.#require(playlistId, userId, "editor");
    transaction(this.db, () => {
      const entry = this.#entry(playlistId, entryId);
      if (!entry) throw new ApiError("TRACK_NOT_FOUND", "Трек не найден в плейлисте", 404);
      this.db.prepare("DELETE FROM collab_tracks WHERE playlist_id = ? AND entry_id = ?").run(playlistId, entryId);
      this.#history(playlistId, userId, { action: "remove", entryId, track: entry.track, position: entry.position });
      this.#touch(playlistId);
    });
  }

  rename(playlistId: string, userId: string, name: string) {
    this.#require(playlistId, userId, "editor");
    transaction(this.db, () => {
      const row = this.db.prepare("SELECT name FROM collab_playlists WHERE id = ?").get(playlistId) as { name: string };
      if (row.name === name) return;
      this.db.prepare("UPDATE collab_playlists SET name = ? WHERE id = ?").run(name, playlistId);
      this.#history(playlistId, userId, { action: "rename", oldName: row.name, newName: name });
      this.#touch(playlistId);
    });
    return this.get(playlistId, userId);
  }

  history(playlistId: string, userId: string, limit = 100): CollabHistoryEntry[] {
    this.#require(playlistId, userId, "viewer");
    return (this.db.prepare("SELECT * FROM collab_history WHERE playlist_id = ? ORDER BY id DESC LIMIT ?")
      .all(playlistId, Math.max(1, Math.min(500, limit))) as HistoryRow[]).map(toHistory);
  }

  /** Applies the inverse of a history entry and records it as a new entry. */
  revert(playlistId: string, userId: string, historyId: number) {
    this.#require(playlistId, userId, "editor");
    return transaction(this.db, () => {
      const row = this.db.prepare("SELECT * FROM collab_history WHERE playlist_id = ? AND id = ?").get(playlistId, historyId) as HistoryRow | undefined;
      if (!row) throw new ApiError("HISTORY_NOT_FOUND", "Запись истории не найдена", 404);
      if (row.reverted_by !== null) throw new ApiError("ALREADY_REVERTED", "Это изменение уже отменено", 409);
      const entry = toHistory(row);
      let inverse: number;
      if (entry.action === "add") {
        const current = this.#entry(playlistId, entry.entryId!);
        if (!current) throw new ApiError("CONFLICT", "Трек уже удалён", 409);
        this.db.prepare("DELETE FROM collab_tracks WHERE playlist_id = ? AND entry_id = ?").run(playlistId, entry.entryId);
        inverse = this.#history(playlistId, userId, { action: "remove", entryId: entry.entryId, track: current.track, position: current.position, revertOf: entry.id });
      } else if (entry.action === "remove") {
        if (this.#entry(playlistId, entry.entryId!)) throw new ApiError("CONFLICT", "Трек уже в плейлисте", 409);
        const count = this.db.prepare("SELECT COUNT(*) AS count FROM collab_tracks WHERE playlist_id = ?").get(playlistId) as { count: number };
        if (Number(count.count) >= this.maxTracks) throw new ApiError("COLLAB_LIMIT", "В плейлисте слишком много треков", 409);
        this.#insertTrack(playlistId, entry.entryId!, entry.track ?? {}, entry.position ?? 0, userId);
        inverse = this.#history(playlistId, userId, { action: "add", entryId: entry.entryId, track: entry.track, position: entry.position, revertOf: entry.id });
      } else {
        const current = this.db.prepare("SELECT name FROM collab_playlists WHERE id = ?").get(playlistId) as { name: string };
        this.db.prepare("UPDATE collab_playlists SET name = ? WHERE id = ?").run(entry.oldName, playlistId);
        inverse = this.#history(playlistId, userId, { action: "rename", oldName: current.name, newName: entry.oldName, revertOf: entry.id });
      }
      this.db.prepare("UPDATE collab_history SET reverted_by = ? WHERE id = ?").run(inverse, entry.id);
      this.#touch(playlistId);
      return this.get(playlistId, userId);
    });
  }

  #insertTrack(playlistId: string, entryId: string, track: Record<string, unknown>, position: number, userId: string) {
    this.db.prepare(`
      INSERT INTO collab_tracks (playlist_id, entry_id, track_json, position, added_by, added_at) VALUES (?, ?, ?, ?, ?, ?)
    `).run(playlistId, entryId, JSON.stringify(track), position, userId, this.now());
  }

  #entry(playlistId: string, entryId: string) {
    const row = this.db.prepare("SELECT * FROM collab_tracks WHERE playlist_id = ? AND entry_id = ?").get(playlistId, entryId) as TrackRow | undefined;
    return row ? toEntry(row) : undefined;
  }

  #history(playlistId: string, userId: string, entry: {
    action: CollabHistoryEntry["action"]; entryId?: string | null; track?: Record<string, unknown> | null; position?: number | null;
    oldName?: string | null; newName?: string | null; revertOf?: number;
  }) {
    const result = this.db.prepare(`
      INSERT INTO collab_history (playlist_id, user_id, action, entry_id, track_json, position, old_name, new_name, revert_of, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      playlistId, userId, entry.action, entry.entryId ?? null, entry.track ? JSON.stringify(entry.track) : null,
      entry.position ?? null, entry.oldName ?? null, entry.newName ?? null, entry.revertOf ?? null, this.now()
    );
    this.db.prepare(`
      DELETE FROM collab_history WHERE playlist_id = ? AND id NOT IN (
        SELECT id FROM collab_history WHERE playlist_id = ? ORDER BY id DESC LIMIT ${MAX_HISTORY}
      )
    `).run(playlistId, playlistId);
    return Number(result.lastInsertRowid);
  }

  #touch(playlistId: string) {
    this.db.prepare("UPDATE collab_playlists SET updated_at = ?, version = version + 1 WHERE id = ?").run(this.now(), playlistId);
  }
}

type TrackRow = { entry_id: string; track_json: string; position: number; added_by: string; added_at: number };
type HistoryRow = {
  id: number; user_id: string; action: string; entry_id: string | null; track_json: string | null; position: number | null;
  old_name: string | null; new_name: string | null; revert_of: number | null; reverted_by: number | null; created_at: number;
};

const parseJson = (value: string | null) => {
  if (!value) return null;
  try { return JSON.parse(value) as Record<string, unknown>; } catch { return null; }
};

const toEntry = (row: TrackRow) => ({
  entryId: row.entry_id,
  track: parseJson(row.track_json) ?? {},
  position: Number(row.position),
  addedBy: row.added_by,
  addedAt: new Date(row.added_at).toISOString()
});

const toHistory = (row: HistoryRow): CollabHistoryEntry => ({
  id: Number(row.id),
  userId: row.user_id,
  action: row.action as CollabHistoryEntry["action"],
  entryId: row.entry_id,
  track: parseJson(row.track_json),
  position: row.position === null ? null : Number(row.position),
  oldName: row.old_name,
  newName: row.new_name,
  revertOf: row.revert_of === null ? null : Number(row.revert_of),
  revertedBy: row.reverted_by === null ? null : Number(row.reverted_by),
  createdAt: new Date(row.created_at).toISOString()
});

const nameSchema = z.string().trim().min(1).max(120);
const idSchema = z.string().uuid();
const userIdSchema = z.string().trim().min(1).max(100);
export const collabTrackSchema = z.object({
  id: z.string().trim().min(1).max(300),
  title: z.string().trim().min(1).max(500),
  artist: z.string().trim().min(1).max(500)
}).passthrough().refine((track) => JSON.stringify(track).length <= 8_192, "Track is too large");

export function createCollabPlaylistRouter(
  store: CollabPlaylistStore,
  authenticate: Authenticate,
  /** Members can only be friends of the owner. */
  canInvite: (ownerId: string, memberId: string) => boolean
) {
  const router = express.Router();
  const writes = new RateGate(120, 60_000);
  router.use((request, response, next) => {
    response.setHeader("cache-control", "private, no-store");
    try {
      response.locals.userId = requireUser(authenticate, request);
      if (request.method !== "GET") writes.check(response.locals.userId as string);
      next();
    } catch (error) {
      handle(() => { throw error; })(request, response);
    }
  });
  const me = (response: express.Response) => response.locals.userId as string;
  const id = (request: express.Request) => parse(idSchema, request.params.id, "Плейлист не найден");

  router.get("/", handle((_request, response) => ({ playlists: store.list(me(response)) })));
  router.post("/", handle((request, response) => {
    const { name } = parse(z.object({ name: nameSchema }).strict(), request.body, "Укажите название");
    response.status(201);
    return { playlist: store.create(me(response), name) };
  }));
  router.get("/:id", handle((request, response) => ({ playlist: store.get(id(request), me(response)) })));
  router.patch("/:id", handle((request, response) => {
    const { name } = parse(z.object({ name: nameSchema }).strict(), request.body, "Укажите название");
    return { playlist: store.rename(id(request), me(response), name) };
  }));
  router.delete("/:id", handle((request, response) => {
    store.delete(id(request), me(response));
    response.status(204).end();
  }));
  router.put("/:id/members/:userId", handle((request, response) => {
    const memberId = parse(userIdSchema, request.params.userId);
    const { role } = parse(z.object({ role: z.enum(["editor", "viewer"]).default("editor") }).strict(), request.body ?? {});
    if (!canInvite(me(response), memberId)) throw new ApiError("NOT_FRIENDS", "Пригласить можно только друга", 403);
    return { playlist: store.setMember(id(request), me(response), memberId, role) };
  }));
  router.delete("/:id/members/:userId", handle((request, response) => {
    store.removeMember(id(request), me(response), parse(userIdSchema, request.params.userId));
    response.status(204).end();
  }));
  router.post("/:id/tracks", handle((request, response) => {
    const body = parse(z.object({
      track: collabTrackSchema,
      position: z.number().min(0).max(1_000_000).optional()
    }).strict(), request.body, "Некорректный трек");
    response.status(201);
    return { entry: store.addTrack(id(request), me(response), body.track, body.position) };
  }));
  router.delete("/:id/tracks/:entryId", handle((request, response) => {
    store.removeTrack(id(request), me(response), parse(idSchema, request.params.entryId, "Трек не найден"));
    response.status(204).end();
  }));
  router.get("/:id/history", handle((request, response) => {
    const limit = parse(z.coerce.number().int().min(1).max(500).default(100), request.query.limit);
    return { history: store.history(id(request), me(response), limit) };
  }));
  router.post("/:id/history/:historyId/revert", handle((request, response) => {
    const historyId = parse(z.coerce.number().int().min(1), request.params.historyId, "Запись не найдена");
    return { playlist: store.revert(id(request), me(response), historyId) };
  }));
  return router;
}
