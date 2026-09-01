import {
  createHash,
  randomBytes,
  randomUUID,
  scrypt as nodeScrypt,
  timingSafeEqual
} from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

const accessLifetimeMs = 60 * 60 * 1_000;
const refreshLifetimeMs = 30 * 24 * 60 * 60 * 1_000;

export type AccountUser = {
  id: string;
  email: string;
  createdAt: string;
};

export type AccountSession = {
  user: AccountUser;
  accessToken: string;
  refreshToken: string;
  accessExpiresAt: string;
  refreshExpiresAt: string;
};

export type LibraryOperation =
  | { id: string; type: "favoriteUpsert"; track: Record<string, unknown> }
  | { id: string; type: "favoriteDelete"; trackId: string }
  | { id: string; type: "playlistUpsert"; playlistId: string; name: string; createdAt: string }
  | { id: string; type: "playlistDelete"; playlistId: string }
  | { id: string; type: "playlistTrackUpsert"; playlistId: string; track: Record<string, unknown>; position: number }
  | { id: string; type: "playlistTrackDelete"; playlistId: string; trackId: string };

export type WaveListeningSignal = {
  type: "started" | "finished" | "skipped" | "liked" | "disliked";
  provider: "soundcloud" | "yandex";
  trackId: string;
  title: string;
  artist: string;
  album?: string;
  playedDurationMs: number;
  createdAt: string;
};

export type WaveTrackSignal = {
  title: string;
  artist: string;
  album?: string;
};

export type WaveTasteSignals = {
  listening: WaveListeningSignal[];
  favorites: WaveTrackSignal[];
  playlistTracks: WaveTrackSignal[];
};

export class AccountError extends Error {
  constructor(
    readonly code: "EMAIL_TAKEN" | "INVALID_CREDENTIALS" | "INVALID_SESSION" | "LIBRARY_LIMIT",
    message: string,
    readonly status: number
  ) {
    super(message);
  }
}

export class AccountStore {
  readonly #database: DatabaseSync;
  readonly #pepper: string;

  constructor(path: string, pepper = "") {
    mkdirSync(dirname(path), { recursive: true });
    this.#database = new DatabaseSync(path);
    this.#pepper = pepper;
    this.#database.exec("PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;");
    this.#database.exec(`
      CREATE TABLE IF NOT EXISTS account_users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS account_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES account_users(id) ON DELETE CASCADE,
        access_hash TEXT NOT NULL UNIQUE,
        refresh_hash TEXT NOT NULL UNIQUE,
        device_name TEXT NOT NULL,
        access_expires_at INTEGER NOT NULL,
        refresh_expires_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_account_sessions_user ON account_sessions(user_id);
      CREATE INDEX IF NOT EXISTS idx_account_sessions_expiry ON account_sessions(refresh_expires_at);
      CREATE TABLE IF NOT EXISTS account_favorites (
        user_id TEXT NOT NULL REFERENCES account_users(id) ON DELETE CASCADE,
        track_id TEXT NOT NULL,
        track_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, track_id)
      );
      CREATE TABLE IF NOT EXISTS account_playlists (
        user_id TEXT NOT NULL REFERENCES account_users(id) ON DELETE CASCADE,
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, id)
      );
      CREATE TABLE IF NOT EXISTS account_playlist_tracks (
        user_id TEXT NOT NULL,
        playlist_id TEXT NOT NULL,
        track_id TEXT NOT NULL,
        track_json TEXT NOT NULL,
        position INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, playlist_id, track_id),
        FOREIGN KEY (user_id, playlist_id) REFERENCES account_playlists(user_id, id) ON DELETE CASCADE
      );
      CREATE INDEX IF NOT EXISTS idx_account_playlist_tracks_position
        ON account_playlist_tracks(user_id, playlist_id, position);
      CREATE TABLE IF NOT EXISTS account_sync_operations (
        user_id TEXT NOT NULL REFERENCES account_users(id) ON DELETE CASCADE,
        operation_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, operation_id)
      );
      CREATE TABLE IF NOT EXISTS account_wave_feedback (
        user_id TEXT NOT NULL REFERENCES account_users(id) ON DELETE CASCADE,
        event_id TEXT NOT NULL,
        type TEXT NOT NULL,
        provider TEXT NOT NULL,
        track_id TEXT NOT NULL,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT,
        played_duration_ms INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, event_id)
      );
      CREATE INDEX IF NOT EXISTS idx_account_wave_feedback_recent
        ON account_wave_feedback(user_id, created_at DESC);
    `);
  }

  close() {
    this.#database.close();
  }

  async register(email: string, password: string, deviceName: string) {
    const id = randomUUID();
    const now = Date.now();
    const salt = randomBytes(16).toString("base64url");
    const passwordHash = await this.#hashPassword(password, salt);
    try {
      return this.#transaction(() => {
        this.#database.prepare(`
          INSERT INTO account_users (id, email, password_hash, password_salt, created_at)
          VALUES (?, ?, ?, ?, ?)
        `).run(id, email, passwordHash, salt, now);
        return this.#issueSession({ id, email, created_at: now }, deviceName);
      });
    } catch (error) {
      if (String(error).includes("UNIQUE constraint failed")) {
        throw new AccountError("EMAIL_TAKEN", "Аккаунт с такой почтой уже существует", 409);
      }
      throw error;
    }
  }

  async login(email: string, password: string, deviceName: string) {
    const row = this.#database.prepare(`
      SELECT id, email, password_hash, password_salt, created_at
      FROM account_users WHERE email = ?
    `).get(email) as UserPasswordRow | undefined;
    const fallbackSalt = randomBytes(16).toString("base64url");
    const actual = await this.#hashPassword(password, row?.password_salt ?? fallbackSalt);
    const valid = row !== undefined && safeEqual(actual, row.password_hash);
    if (!valid || !row) {
      throw new AccountError("INVALID_CREDENTIALS", "Неверная почта или пароль", 401);
    }
    return this.#issueSession(row, deviceName);
  }

  authenticate(accessToken: string) {
    const now = Date.now();
    const row = this.#database.prepare(`
      SELECT u.id, u.email, u.created_at
      FROM account_sessions s
      JOIN account_users u ON u.id = s.user_id
      WHERE s.access_hash = ? AND s.access_expires_at > ? AND s.refresh_expires_at > ?
    `).get(tokenHash(accessToken), now, now) as UserRow | undefined;
    if (!row) throw new AccountError("INVALID_SESSION", "Сессия истекла", 401);
    return publicUser(row);
  }

  refresh(refreshToken: string, deviceName: string) {
    const now = Date.now();
    const row = this.#database.prepare(`
      SELECT s.id AS session_id, u.id, u.email, u.created_at
      FROM account_sessions s
      JOIN account_users u ON u.id = s.user_id
      WHERE s.refresh_hash = ? AND s.refresh_expires_at > ?
    `).get(tokenHash(refreshToken), now) as RefreshRow | undefined;
    if (!row) throw new AccountError("INVALID_SESSION", "Сессия истекла", 401);
    return this.#transaction(() => {
      this.#database.prepare("DELETE FROM account_sessions WHERE id = ?").run(row.session_id);
      return this.#issueSession(row, deviceName);
    });
  }

  logout(refreshToken: string) {
    this.#database.prepare("DELETE FROM account_sessions WHERE refresh_hash = ?")
      .run(tokenHash(refreshToken));
  }

  getLibrary(userId: string) {
    const favorites = this.#database.prepare(`
      SELECT track_json FROM account_favorites WHERE user_id = ? ORDER BY updated_at DESC
    `).all(userId).map((row) => parseTrack((row as { track_json: string }).track_json));
    const playlistRows = this.#database.prepare(`
      SELECT id, name, created_at, updated_at
      FROM account_playlists WHERE user_id = ? ORDER BY updated_at DESC
    `).all(userId) as unknown as PlaylistRow[];
    const trackStatement = this.#database.prepare(`
      SELECT track_json, position FROM account_playlist_tracks
      WHERE user_id = ? AND playlist_id = ? ORDER BY position, added_at
    `);
    const playlists = playlistRows.map((playlist) => ({
      id: playlist.id,
      name: playlist.name,
      createdAt: new Date(playlist.created_at).toISOString(),
      updatedAt: new Date(playlist.updated_at).toISOString(),
      tracks: trackStatement.all(userId, playlist.id).map((row) => ({
        position: Number((row as { position: number }).position),
        track: parseTrack((row as { track_json: string }).track_json)
      }))
    }));
    return { favorites, playlists };
  }

  getWaveTasteSignals(userId: string): WaveTasteSignals {
    const library = this.getLibrary(userId);
    const favorites = library.favorites
      .map(waveTrackSignal)
      .filter((track): track is WaveTrackSignal => track !== undefined)
      .slice(0, 100);
    const playlistTracks = library.playlists
      .flatMap((playlist) => playlist.tracks.map((entry) => waveTrackSignal(entry.track)))
      .filter((track): track is WaveTrackSignal => track !== undefined)
      .slice(0, 200);
    const listening = this.#database.prepare(`
      SELECT type, provider, track_id, title, artist, album, played_duration_ms, created_at
      FROM account_wave_feedback WHERE user_id = ?
      ORDER BY created_at DESC LIMIT 200
    `).all(userId).map((raw) => {
      const row = raw as WaveFeedbackRow;
      return {
        type: row.type,
        provider: row.provider,
        trackId: row.track_id,
        title: row.title,
        artist: row.artist,
        ...(row.album ? { album: row.album } : {}),
        playedDurationMs: row.played_duration_ms,
        createdAt: new Date(row.created_at).toISOString()
      };
    });
    return { listening, favorites, playlistTracks };
  }

  recordWaveFeedback(
    userId: string,
    event: Omit<WaveListeningSignal, "title" | "artist" | "album" | "createdAt"> & { eventId: string },
    track: WaveTrackSignal
  ) {
    const now = Date.now();
    this.#database.prepare(`
      INSERT OR IGNORE INTO account_wave_feedback (
        user_id, event_id, type, provider, track_id, title, artist, album, played_duration_ms, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      userId,
      event.eventId,
      event.type,
      event.provider,
      event.trackId,
      track.title,
      track.artist,
      track.album ?? null,
      Math.max(0, Math.trunc(event.playedDurationMs)),
      now
    );
    this.#database.prepare(`
      DELETE FROM account_wave_feedback
      WHERE user_id = ? AND event_id NOT IN (
        SELECT event_id FROM account_wave_feedback
        WHERE user_id = ? ORDER BY created_at DESC LIMIT 2000
      )
    `).run(userId, userId);
  }

  applyOperations(userId: string, operations: LibraryOperation[]) {
    const seen = this.#database.prepare(`
      SELECT 1 FROM account_sync_operations WHERE user_id = ? AND operation_id = ?
    `);
    const remember = this.#database.prepare(`
      INSERT INTO account_sync_operations (user_id, operation_id, created_at) VALUES (?, ?, ?)
    `);
    this.#database.exec("BEGIN IMMEDIATE");
    try {
      for (const operation of operations) {
        if (seen.get(userId, operation.id)) continue;
        this.#applyOperation(userId, operation);
        remember.run(userId, operation.id, Date.now());
      }
      this.#assertLibraryQuota(userId);
      this.#database.prepare(`
        DELETE FROM account_sync_operations
        WHERE user_id = ? AND operation_id NOT IN (
          SELECT operation_id FROM account_sync_operations
          WHERE user_id = ? ORDER BY created_at DESC LIMIT 10000
        )
      `).run(userId, userId);
      this.#database.exec("COMMIT");
    } catch (error) {
      this.#database.exec("ROLLBACK");
      throw error;
    }
    return this.getLibrary(userId);
  }

  prune() {
    const now = Date.now();
    this.#database.prepare("DELETE FROM account_sessions WHERE refresh_expires_at <= ?").run(now);
    this.#database.prepare(`
      DELETE FROM account_sync_operations WHERE created_at < ?
    `).run(now - 90 * 24 * 60 * 60 * 1_000);
    this.#database.prepare("DELETE FROM account_wave_feedback WHERE created_at < ?")
      .run(now - 180 * 24 * 60 * 60 * 1_000);
  }

  #applyOperation(userId: string, operation: LibraryOperation) {
    const now = Date.now();
    switch (operation.type) {
      case "favoriteUpsert":
        this.#database.prepare(`
          INSERT INTO account_favorites (user_id, track_id, track_json, updated_at)
          VALUES (?, ?, ?, ?)
          ON CONFLICT(user_id, track_id) DO UPDATE SET track_json = excluded.track_json, updated_at = excluded.updated_at
        `).run(userId, String(operation.track.id), JSON.stringify(operation.track), now);
        break;
      case "favoriteDelete":
        this.#database.prepare("DELETE FROM account_favorites WHERE user_id = ? AND track_id = ?")
          .run(userId, operation.trackId);
        break;
      case "playlistUpsert":
        this.#database.prepare(`
          INSERT INTO account_playlists (user_id, id, name, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(user_id, id) DO UPDATE SET name = excluded.name, updated_at = excluded.updated_at
        `).run(userId, operation.playlistId, operation.name, Date.parse(operation.createdAt), now);
        break;
      case "playlistDelete":
        this.#database.prepare("DELETE FROM account_playlists WHERE user_id = ? AND id = ?")
          .run(userId, operation.playlistId);
        break;
      case "playlistTrackUpsert":
        this.#database.prepare(`
          INSERT INTO account_playlist_tracks (user_id, playlist_id, track_id, track_json, position, added_at)
          VALUES (?, ?, ?, ?, ?, ?)
          ON CONFLICT(user_id, playlist_id, track_id) DO UPDATE SET
            track_json = excluded.track_json, position = excluded.position
        `).run(
          userId,
          operation.playlistId,
          String(operation.track.id),
          JSON.stringify(operation.track),
          operation.position,
          now
        );
        this.#database.prepare(`
          UPDATE account_playlists SET updated_at = ? WHERE user_id = ? AND id = ?
        `).run(now, userId, operation.playlistId);
        break;
      case "playlistTrackDelete":
        this.#database.prepare(`
          DELETE FROM account_playlist_tracks WHERE user_id = ? AND playlist_id = ? AND track_id = ?
        `).run(userId, operation.playlistId, operation.trackId);
        this.#database.prepare(`
          UPDATE account_playlists SET updated_at = ? WHERE user_id = ? AND id = ?
        `).run(now, userId, operation.playlistId);
        break;
    }
  }

  #assertLibraryQuota(userId: string) {
    const counts = this.#database.prepare(`
      SELECT
        (SELECT COUNT(*) FROM account_favorites WHERE user_id = ?) AS favorites,
        (SELECT COUNT(*) FROM account_playlists WHERE user_id = ?) AS playlists,
        (SELECT COUNT(*) FROM account_playlist_tracks WHERE user_id = ?) AS playlist_tracks,
        (SELECT COALESCE(SUM(LENGTH(track_json)), 0) FROM account_favorites WHERE user_id = ?) +
        (SELECT COALESCE(SUM(LENGTH(track_json)), 0) FROM account_playlist_tracks WHERE user_id = ?) AS track_bytes
    `).get(userId, userId, userId, userId, userId) as {
      favorites: number;
      playlists: number;
      playlist_tracks: number;
      track_bytes: number;
    };
    if (
      counts.favorites > 2_000 ||
      counts.playlists > 200 ||
      counts.playlist_tracks > 10_000 ||
      counts.track_bytes > 20 * 1024 * 1024
    ) {
      throw new AccountError(
        "LIBRARY_LIMIT",
        "Достигнут лимит облачной медиатеки",
        413
      );
    }
  }

  #transaction<T>(callback: () => T): T {
    this.#database.exec("BEGIN IMMEDIATE");
    try {
      const result = callback();
      this.#database.exec("COMMIT");
      return result;
    } catch (error) {
      this.#database.exec("ROLLBACK");
      throw error;
    }
  }

  async #hashPassword(password: string, salt: string) {
    return new Promise<string>((resolve, reject) => {
      nodeScrypt(
        `${password}${this.#pepper}`,
        salt,
        64,
        { N: 1 << 15, r: 8, p: 1, maxmem: 64 * 1024 * 1024 },
        (error, derivedKey) => error
          ? reject(error)
          : resolve(derivedKey.toString("base64url"))
      );
    });
  }

  #issueSession(user: UserRow, deviceName: string): AccountSession {
    this.prune();
    const now = Date.now();
    const accessToken = randomBytes(32).toString("base64url");
    const refreshToken = randomBytes(48).toString("base64url");
    const accessExpiresAt = now + accessLifetimeMs;
    const refreshExpiresAt = now + refreshLifetimeMs;
    this.#database.prepare(`
      INSERT INTO account_sessions (
        id, user_id, access_hash, refresh_hash, device_name,
        access_expires_at, refresh_expires_at, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      randomUUID(),
      user.id,
      tokenHash(accessToken),
      tokenHash(refreshToken),
      deviceName,
      accessExpiresAt,
      refreshExpiresAt,
      now
    );
    this.#database.prepare(`
      DELETE FROM account_sessions
      WHERE user_id = ? AND id NOT IN (
        SELECT id FROM account_sessions
        WHERE user_id = ? ORDER BY created_at DESC LIMIT 20
      )
    `).run(user.id, user.id);
    return {
      user: publicUser(user),
      accessToken,
      refreshToken,
      accessExpiresAt: new Date(accessExpiresAt).toISOString(),
      refreshExpiresAt: new Date(refreshExpiresAt).toISOString()
    };
  }
}

type UserRow = { id: string; email: string; created_at: number };
type UserPasswordRow = UserRow & { password_hash: string; password_salt: string };
type RefreshRow = UserRow & { session_id: string };
type PlaylistRow = { id: string; name: string; created_at: number; updated_at: number };
type WaveFeedbackRow = {
  type: WaveListeningSignal["type"];
  provider: WaveListeningSignal["provider"];
  track_id: string;
  title: string;
  artist: string;
  album: string | null;
  played_duration_ms: number;
  created_at: number;
};

const publicUser = (row: UserRow): AccountUser => ({
  id: row.id,
  email: row.email,
  createdAt: new Date(row.created_at).toISOString()
});

const tokenHash = (token: string) => createHash("sha256").update(token).digest("hex");

const safeEqual = (left: string, right: string) => {
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  return a.length === b.length && timingSafeEqual(a, b);
};

const parseTrack = (value: string) => JSON.parse(value) as Record<string, unknown>;

const waveTrackSignal = (track: Record<string, unknown>): WaveTrackSignal | undefined => {
  const title = typeof track.title === "string" ? track.title.trim() : "";
  const artist = typeof track.artist === "string" ? track.artist.trim() : "";
  if (!title || !artist) return undefined;
  const album = typeof track.album === "string" ? track.album.trim() : "";
  return { title, artist, ...(album ? { album } : {}) };
};
