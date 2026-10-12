import { randomBytes } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import { ApiError, transaction } from "./api-helpers.js";
import { normalize } from "./wave.js";

export type ReleaseChannel = "stable" | "beta";

export type SocialProfile = {
  userId: string;
  displayName: string;
  handle: string | null;
  /** Profile can be found by search/handle. Hidden by default. */
  isPublic: boolean;
  /** Friends see what this account is listening to. Off by default. */
  shareListening: boolean;
  /** Friends see the room this account is in. Off by default. */
  shareRooms: boolean;
  inviteCode: string;
  updatedAt: string;
};

export type PublicProfile = Pick<SocialProfile, "userId" | "displayName" | "handle">;

export type FriendRelation = "none" | "friends" | "outgoing" | "incoming" | "blocked";

export type ArtistFollow = { artist: string; key: string; followedAt: string; seenAt: string };

const handlePattern = /^[a-z0-9_.]{3,24}$/u;

/**
 * Social graph of Resonance accounts: profiles with privacy defaults (hidden),
 * friend requests, blocks, release-channel choice and artist follows.
 * Lives in its own SQLite file next to the account database.
 */
export class SocialStore {
  constructor(private readonly db: DatabaseSync, private readonly now: () => number = Date.now) {
    db.exec(`
      CREATE TABLE IF NOT EXISTS social_profiles (
        user_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        handle TEXT UNIQUE COLLATE NOCASE,
        is_public INTEGER NOT NULL DEFAULT 0,
        share_listening INTEGER NOT NULL DEFAULT 0,
        share_rooms INTEGER NOT NULL DEFAULT 0,
        invite_code TEXT NOT NULL UNIQUE,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS social_requests (
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (from_id, to_id)
      );
      CREATE INDEX IF NOT EXISTS idx_social_requests_to ON social_requests(to_id);
      CREATE TABLE IF NOT EXISTS social_friends (
        user_id TEXT NOT NULL,
        friend_id TEXT NOT NULL,
        since INTEGER NOT NULL,
        PRIMARY KEY (user_id, friend_id)
      );
      CREATE TABLE IF NOT EXISTS social_blocks (
        user_id TEXT NOT NULL,
        blocked_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, blocked_id)
      );
      CREATE TABLE IF NOT EXISTS account_channels (
        user_id TEXT PRIMARY KEY,
        channel TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS artist_follows (
        user_id TEXT NOT NULL,
        artist_key TEXT NOT NULL,
        artist_name TEXT NOT NULL,
        followed_at INTEGER NOT NULL,
        seen_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, artist_key)
      );
      CREATE TABLE IF NOT EXISTS artist_release_seen (
        user_id TEXT NOT NULL,
        release_id TEXT NOT NULL,
        seen_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, release_id)
      );
    `);
  }

  // ---- profiles -----------------------------------------------------------

  profile(userId: string): SocialProfile {
    const existing = this.#row(userId);
    if (existing) return existing;
    const now = this.now();
    this.db.prepare(`
      INSERT OR IGNORE INTO social_profiles (user_id, display_name, invite_code, updated_at) VALUES (?, ?, ?, ?)
    `).run(userId, "Слушатель", randomBytes(9).toString("base64url"), now);
    return this.#row(userId)!;
  }

  hasProfile(userId: string) {
    return this.#row(userId) !== undefined;
  }

  updateProfile(userId: string, patch: Partial<Pick<SocialProfile, "displayName" | "handle" | "isPublic" | "shareListening" | "shareRooms">>) {
    const current = this.profile(userId);
    const handle = patch.handle === undefined ? current.handle : patch.handle === null ? null : patch.handle.trim().toLowerCase();
    if (handle !== null && !handlePattern.test(handle)) {
      throw new ApiError("INVALID_HANDLE", "Имя пользователя: 3–24 символа, латиница, цифры, «_» и «.»", 400);
    }
    try {
      this.db.prepare(`
        UPDATE social_profiles SET display_name = ?, handle = ?, is_public = ?, share_listening = ?, share_rooms = ?, updated_at = ?
        WHERE user_id = ?
      `).run(
        (patch.displayName ?? current.displayName).trim().slice(0, 40) || "Слушатель",
        handle,
        (patch.isPublic ?? current.isPublic) ? 1 : 0,
        (patch.shareListening ?? current.shareListening) ? 1 : 0,
        (patch.shareRooms ?? current.shareRooms) ? 1 : 0,
        this.now(),
        userId
      );
    } catch (error) {
      if (String(error).includes("UNIQUE")) throw new ApiError("HANDLE_TAKEN", "Это имя пользователя уже занято", 409);
      throw error;
    }
    return this.profile(userId);
  }

  rotateInvite(userId: string) {
    this.profile(userId);
    this.db.prepare("UPDATE social_profiles SET invite_code = ?, updated_at = ? WHERE user_id = ?")
      .run(randomBytes(9).toString("base64url"), this.now(), userId);
    return this.profile(userId);
  }

  /** Public profiles only; hidden profiles are reachable solely through their invite code. */
  search(viewerId: string, query: string, limit = 20): PublicProfile[] {
    const needle = query.trim().toLowerCase().replace(/[%_\\]/g, "");
    if (needle.length < 2) return [];
    const rows = this.db.prepare(`
      SELECT * FROM social_profiles
      WHERE is_public = 1 AND user_id != ?
        AND (handle LIKE ? OR LOWER(display_name) LIKE ?)
      LIMIT ?
    `).all(viewerId, `${needle}%`, `%${needle}%`, Math.min(50, limit * 2)) as ProfileRow[];
    return rows.map(toProfile)
      .filter((profile) => !this.isBlockedEitherWay(viewerId, profile.userId))
      .slice(0, limit)
      .map(publicProfile);
  }

  resolveTarget(viewerId: string, target: { userId?: string; handle?: string; inviteCode?: string }) {
    let row: ProfileRow | undefined;
    if (target.inviteCode) {
      row = this.db.prepare("SELECT * FROM social_profiles WHERE invite_code = ?").get(target.inviteCode) as ProfileRow | undefined;
    } else if (target.handle) {
      row = this.db.prepare("SELECT * FROM social_profiles WHERE handle = ? AND is_public = 1")
        .get(target.handle.trim().toLowerCase()) as ProfileRow | undefined;
    } else if (target.userId) {
      row = this.db.prepare("SELECT * FROM social_profiles WHERE user_id = ?").get(target.userId) as ProfileRow | undefined;
      // A hidden profile is only addressable by id when a relation already exists.
      if (row && !row.is_public && this.relation(viewerId, row.user_id) === "none") row = undefined;
    }
    if (!row || row.user_id === viewerId || this.#blocks(row.user_id, viewerId)) {
      throw new ApiError("USER_NOT_FOUND", "Пользователь не найден", 404);
    }
    return toProfile(row);
  }

  /** What `viewerId` may see about `userId`, or undefined when nothing. */
  visibleProfile(viewerId: string, userId: string): (PublicProfile & { relation: FriendRelation }) | undefined {
    const row = this.#row(userId);
    if (!row || this.#blocks(userId, viewerId)) return undefined;
    const relation = this.relation(viewerId, userId);
    if (!row.isPublic && relation === "none") return undefined;
    return { ...publicProfile(row), relation };
  }

  // ---- friends ------------------------------------------------------------

  relation(userId: string, otherId: string): FriendRelation {
    if (this.#blocks(userId, otherId)) return "blocked";
    if (this.areFriends(userId, otherId)) return "friends";
    if (this.db.prepare("SELECT 1 FROM social_requests WHERE from_id = ? AND to_id = ?").get(userId, otherId)) return "outgoing";
    if (this.db.prepare("SELECT 1 FROM social_requests WHERE from_id = ? AND to_id = ?").get(otherId, userId)) return "incoming";
    return "none";
  }

  areFriends(userId: string, otherId: string) {
    return this.db.prepare("SELECT 1 FROM social_friends WHERE user_id = ? AND friend_id = ?").get(userId, otherId) !== undefined;
  }

  isBlockedEitherWay(userId: string, otherId: string) {
    return this.#blocks(userId, otherId) || this.#blocks(otherId, userId);
  }

  request(fromId: string, toId: string): FriendRelation {
    if (fromId === toId) throw new ApiError("INVALID_REQUEST", "Нельзя добавить себя в друзья", 400);
    if (this.isBlockedEitherWay(fromId, toId)) throw new ApiError("USER_NOT_FOUND", "Пользователь не найден", 404);
    const relation = this.relation(fromId, toId);
    if (relation === "friends" || relation === "outgoing") return relation;
    if (relation === "incoming") return this.accept(fromId, toId);
    const pending = this.db.prepare("SELECT COUNT(*) AS count FROM social_requests WHERE from_id = ?").get(fromId) as { count: number };
    if (Number(pending.count) >= 200) throw new ApiError("FRIEND_LIMIT", "Слишком много неотвеченных заявок", 429);
    this.db.prepare("INSERT OR IGNORE INTO social_requests (from_id, to_id, created_at) VALUES (?, ?, ?)").run(fromId, toId, this.now());
    return "outgoing";
  }

  accept(userId: string, fromId: string): FriendRelation {
    const exists = this.db.prepare("SELECT 1 FROM social_requests WHERE from_id = ? AND to_id = ?").get(fromId, userId);
    if (!exists) throw new ApiError("REQUEST_NOT_FOUND", "Заявка не найдена", 404);
    const friends = this.db.prepare("SELECT COUNT(*) AS count FROM social_friends WHERE user_id = ?").get(userId) as { count: number };
    if (Number(friends.count) >= 1_000) throw new ApiError("FRIEND_LIMIT", "Достигнут лимит друзей", 409);
    transaction(this.db, () => {
      this.db.prepare("DELETE FROM social_requests WHERE (from_id = ? AND to_id = ?) OR (from_id = ? AND to_id = ?)")
        .run(fromId, userId, userId, fromId);
      const insert = this.db.prepare("INSERT OR IGNORE INTO social_friends (user_id, friend_id, since) VALUES (?, ?, ?)");
      insert.run(userId, fromId, this.now());
      insert.run(fromId, userId, this.now());
    });
    return "friends";
  }

  /** Declines an incoming request or cancels an outgoing one. */
  dropRequest(userId: string, otherId: string) {
    this.db.prepare("DELETE FROM social_requests WHERE (from_id = ? AND to_id = ?) OR (from_id = ? AND to_id = ?)")
      .run(otherId, userId, userId, otherId);
  }

  removeFriend(userId: string, friendId: string) {
    this.db.prepare("DELETE FROM social_friends WHERE (user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)")
      .run(userId, friendId, friendId, userId);
  }

  block(userId: string, targetId: string) {
    if (userId === targetId) throw new ApiError("INVALID_REQUEST", "Нельзя заблокировать себя", 400);
    transaction(this.db, () => {
      this.removeFriend(userId, targetId);
      this.dropRequest(userId, targetId);
      this.db.prepare("INSERT OR IGNORE INTO social_blocks (user_id, blocked_id, created_at) VALUES (?, ?, ?)")
        .run(userId, targetId, this.now());
    });
  }

  unblock(userId: string, targetId: string) {
    this.db.prepare("DELETE FROM social_blocks WHERE user_id = ? AND blocked_id = ?").run(userId, targetId);
  }

  friendIds(userId: string): string[] {
    return (this.db.prepare("SELECT friend_id FROM social_friends WHERE user_id = ? ORDER BY since DESC").all(userId) as Array<{ friend_id: string }>)
      .map((row) => row.friend_id);
  }

  overview(userId: string) {
    const card = (id: string) => ({ ...publicProfile(this.profile(id)) });
    const friends = (this.db.prepare("SELECT friend_id, since FROM social_friends WHERE user_id = ? ORDER BY since DESC").all(userId) as Array<{ friend_id: string; since: number }>)
      .map((row) => ({ ...card(row.friend_id), since: new Date(row.since).toISOString() }));
    const incoming = (this.db.prepare("SELECT from_id, created_at FROM social_requests WHERE to_id = ? ORDER BY created_at DESC").all(userId) as Array<{ from_id: string; created_at: number }>)
      .map((row) => ({ ...card(row.from_id), requestedAt: new Date(row.created_at).toISOString() }));
    const outgoing = (this.db.prepare("SELECT to_id, created_at FROM social_requests WHERE from_id = ? ORDER BY created_at DESC").all(userId) as Array<{ to_id: string; created_at: number }>)
      .map((row) => ({ ...card(row.to_id), requestedAt: new Date(row.created_at).toISOString() }));
    const blocked = (this.db.prepare("SELECT blocked_id FROM social_blocks WHERE user_id = ? ORDER BY created_at DESC").all(userId) as Array<{ blocked_id: string }>)
      .map((row) => card(row.blocked_id));
    return { friends, incoming, outgoing, blocked };
  }

  // ---- release channel ----------------------------------------------------

  channel(userId: string): ReleaseChannel {
    const row = this.db.prepare("SELECT channel FROM account_channels WHERE user_id = ?").get(userId) as { channel: string } | undefined;
    return row?.channel === "beta" ? "beta" : "stable";
  }

  setChannel(userId: string, channel: ReleaseChannel) {
    this.db.prepare(`
      INSERT INTO account_channels (user_id, channel, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET channel = excluded.channel, updated_at = excluded.updated_at
    `).run(userId, channel, this.now());
    return channel;
  }

  // ---- artist follows -----------------------------------------------------

  follow(userId: string, artist: string): ArtistFollow {
    const key = normalize(artist);
    if (!key) throw new ApiError("INVALID_REQUEST", "Укажите артиста", 400);
    const count = this.db.prepare("SELECT COUNT(*) AS count FROM artist_follows WHERE user_id = ?").get(userId) as { count: number };
    const existing = this.db.prepare("SELECT 1 FROM artist_follows WHERE user_id = ? AND artist_key = ?").get(userId, key);
    if (!existing && Number(count.count) >= 500) throw new ApiError("FOLLOW_LIMIT", "Можно следить не более чем за 500 артистами", 409);
    const now = this.now();
    this.db.prepare(`
      INSERT INTO artist_follows (user_id, artist_key, artist_name, followed_at, seen_at) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(user_id, artist_key) DO UPDATE SET artist_name = excluded.artist_name
    `).run(userId, key, artist.trim().slice(0, 200), now, now);
    return this.follows(userId).find((entry) => entry.key === key)!;
  }

  unfollow(userId: string, artist: string) {
    this.db.prepare("DELETE FROM artist_follows WHERE user_id = ? AND artist_key = ?").run(userId, normalize(artist));
  }

  isFollowing(userId: string, artist: string) {
    return this.db.prepare("SELECT 1 FROM artist_follows WHERE user_id = ? AND artist_key = ?").get(userId, normalize(artist)) !== undefined;
  }

  follows(userId: string): ArtistFollow[] {
    return (this.db.prepare("SELECT * FROM artist_follows WHERE user_id = ? ORDER BY followed_at DESC").all(userId) as Array<{
      artist_key: string; artist_name: string; followed_at: number; seen_at: number;
    }>).map((row) => ({
      artist: row.artist_name,
      key: row.artist_key,
      followedAt: new Date(row.followed_at).toISOString(),
      seenAt: new Date(row.seen_at).toISOString()
    }));
  }

  /** Records release ids as read; also bumps the follow's `seenAt`. Keeps the newest 2000 ids. */
  markReleasesSeen(userId: string, releaseIds: string[], artist?: string) {
    const now = this.now();
    transaction(this.db, () => {
      const insert = this.db.prepare("INSERT OR IGNORE INTO artist_release_seen (user_id, release_id, seen_at) VALUES (?, ?, ?)");
      for (const id of releaseIds.slice(0, 500)) insert.run(userId, id, now);
      if (artist) {
        this.db.prepare("UPDATE artist_follows SET seen_at = ? WHERE user_id = ? AND artist_key = ?").run(now, userId, normalize(artist));
      } else {
        this.db.prepare("UPDATE artist_follows SET seen_at = ? WHERE user_id = ?").run(now, userId);
      }
      this.db.prepare(`
        DELETE FROM artist_release_seen WHERE user_id = ? AND rowid NOT IN (
          SELECT rowid FROM artist_release_seen WHERE user_id = ? ORDER BY seen_at DESC LIMIT 2000
        )
      `).run(userId, userId);
    });
  }

  seenReleaseIds(userId: string) {
    return new Set((this.db.prepare("SELECT release_id FROM artist_release_seen WHERE user_id = ?").all(userId) as Array<{ release_id: string }>)
      .map((row) => row.release_id));
  }

  #row(userId: string) {
    const row = this.db.prepare("SELECT * FROM social_profiles WHERE user_id = ?").get(userId) as ProfileRow | undefined;
    return row ? toProfile(row) : undefined;
  }

  #blocks(userId: string, otherId: string) {
    return this.db.prepare("SELECT 1 FROM social_blocks WHERE user_id = ? AND blocked_id = ?").get(userId, otherId) !== undefined;
  }
}

type ProfileRow = {
  user_id: string;
  display_name: string;
  handle: string | null;
  is_public: number;
  share_listening: number;
  share_rooms: number;
  invite_code: string;
  updated_at: number;
};

const toProfile = (row: ProfileRow): SocialProfile => ({
  userId: row.user_id,
  displayName: row.display_name,
  handle: row.handle,
  isPublic: Number(row.is_public) === 1,
  shareListening: Number(row.share_listening) === 1,
  shareRooms: Number(row.share_rooms) === 1,
  inviteCode: row.invite_code,
  updatedAt: new Date(row.updated_at).toISOString()
});

export const publicProfile = (profile: SocialProfile): PublicProfile => ({
  userId: profile.userId,
  displayName: profile.displayName,
  handle: profile.handle
});
