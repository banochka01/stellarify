import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";
import type { ProviderName, ProviderTrack } from "./provider-gateway.js";
import type { MatchConfidence } from "./track-matcher.js";

export type MigrationSource = "yandex" | "spotify" | "vk";
export type MigrationTarget = ProviderName;
export type MigrationKind = "full" | "resync";
export type MigrationStatus =
  | "queued"
  | "fetching"
  | "matching"
  | "saving"
  | "completed"
  | "paused"
  | "failed";
export type MigrationSection = "favorite" | "playlist" | "album";
export type MigrationItemStatus = "pending" | "matched" | "confirmed" | "replaced" | "unmatched";

export interface MigrationCollection {
  id: string;
  kind: "playlist" | "album";
  title: string;
  artist?: string;
  artworkUrl?: string;
  trackCount: number;
}

export interface MigrationArtist {
  externalId: string;
  name: string;
  artworkUrl?: string;
}

export interface MigrationJob {
  id: string;
  userId: string;
  source: MigrationSource;
  target: MigrationTarget;
  kind: MigrationKind;
  status: MigrationStatus;
  total: number;
  processed: number;
  error?: string;
  warning?: string;
  truncated: boolean;
  collections: MigrationCollection[];
  artists: MigrationArtist[];
  createdAt: string;
  updatedAt: string;
  completedAt?: string;
}

export interface MigrationItem {
  jobId: string;
  itemId: number;
  section: MigrationSection;
  collectionId?: string;
  position: number;
  sourceKey: string;
  source: ProviderTrack;
  status: MigrationItemStatus;
  confidence: MatchConfidence | null;
  score: number | null;
  match?: ProviderTrack & { provider: ProviderName };
  libraryTrackId?: string;
}

export interface NewMigrationItem {
  section: MigrationSection;
  collectionId?: string;
  position: number;
  sourceKey: string;
  source: ProviderTrack;
}

const activeStatuses: MigrationStatus[] = ["queued", "fetching", "matching", "saving"];

/**
 * Persists migration jobs next to the Resonance ID account database. Provider
 * tokens are never written here; a job interrupted by a restart is parked as
 * "paused" and resumed when the client supplies tokens again.
 */
export class MigrationStore {
  readonly #db: DatabaseSync;

  constructor(path: string, private readonly now: () => number = Date.now) {
    if (path !== ":memory:") mkdirSync(dirname(path), { recursive: true });
    this.#db = new DatabaseSync(path);
    this.#db.exec("PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;");
    this.#db.exec(`
      CREATE TABLE IF NOT EXISTS migration_jobs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        source TEXT NOT NULL,
        target TEXT NOT NULL,
        kind TEXT NOT NULL,
        status TEXT NOT NULL,
        total INTEGER NOT NULL DEFAULT 0,
        processed INTEGER NOT NULL DEFAULT 0,
        error TEXT,
        warning TEXT,
        truncated INTEGER NOT NULL DEFAULT 0,
        collections_json TEXT NOT NULL DEFAULT '[]',
        artists_json TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        completed_at INTEGER
      );
      CREATE INDEX IF NOT EXISTS idx_migration_jobs_user ON migration_jobs(user_id, created_at DESC);
      CREATE TABLE IF NOT EXISTS migration_items (
        job_id TEXT NOT NULL REFERENCES migration_jobs(id) ON DELETE CASCADE,
        item_id INTEGER NOT NULL,
        section TEXT NOT NULL,
        collection_id TEXT,
        position INTEGER NOT NULL,
        source_key TEXT NOT NULL,
        source_json TEXT NOT NULL,
        status TEXT NOT NULL,
        confidence TEXT,
        score REAL,
        match_json TEXT,
        library_track_id TEXT,
        PRIMARY KEY (job_id, item_id)
      );
      CREATE INDEX IF NOT EXISTS idx_migration_items_status ON migration_items(job_id, status);
      CREATE TABLE IF NOT EXISTS migration_seen (
        user_id TEXT NOT NULL,
        source TEXT NOT NULL,
        source_key TEXT NOT NULL,
        seen_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, source, source_key)
      );
      CREATE TABLE IF NOT EXISTS migration_sync_state (
        user_id TEXT NOT NULL,
        source TEXT NOT NULL,
        last_synced_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, source)
      );
    `);
  }

  close() {
    this.#db.close();
  }

  /** Parks jobs that were running when the process stopped. */
  pauseInterrupted() {
    const placeholders = activeStatuses.map(() => "?").join(",");
    this.#db.prepare(`
      UPDATE migration_jobs SET status = 'paused', error = ?, updated_at = ?
      WHERE status IN (${placeholders})
    `).run("Перенос прервался. Нажмите «Продолжить», чтобы докончить его.", this.now(), ...activeStatuses);
  }

  createJob(job: Pick<MigrationJob, "id" | "userId" | "source" | "target" | "kind">) {
    const now = this.now();
    this.#db.prepare(`
      INSERT INTO migration_jobs (id, user_id, source, target, kind, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, 'queued', ?, ?)
    `).run(job.id, job.userId, job.source, job.target, job.kind, now, now);
    return this.getJob(job.id)!;
  }

  getJob(id: string): MigrationJob | undefined {
    const row = this.#db.prepare("SELECT * FROM migration_jobs WHERE id = ?").get(id) as JobRow | undefined;
    return row ? jobFromRow(row) : undefined;
  }

  listJobs(userId: string, limit = 20) {
    return (this.#db.prepare(`
      SELECT * FROM migration_jobs WHERE user_id = ? ORDER BY created_at DESC LIMIT ?
    `).all(userId, limit) as unknown as JobRow[]).map(jobFromRow);
  }

  activeJob(userId: string) {
    const placeholders = activeStatuses.map(() => "?").join(",");
    const row = this.#db.prepare(`
      SELECT * FROM migration_jobs WHERE user_id = ? AND status IN (${placeholders})
      ORDER BY created_at DESC LIMIT 1
    `).get(userId, ...activeStatuses) as JobRow | undefined;
    return row ? jobFromRow(row) : undefined;
  }

  updateJob(id: string, patch: Partial<Pick<MigrationJob,
    "status" | "error" | "warning" | "truncated" | "collections" | "artists" | "total" | "processed"
  >>) {
    const sets: string[] = ["updated_at = ?"];
    const values: Array<string | number | null> = [this.now()];
    const set = (column: string, value: string | number | null) => {
      sets.push(`${column} = ?`);
      values.push(value);
    };
    if (patch.status !== undefined) {
      set("status", patch.status);
      if (patch.status === "completed") set("completed_at", this.now());
    }
    if ("error" in patch) set("error", patch.error ?? null);
    if ("warning" in patch) set("warning", patch.warning ?? null);
    if (patch.truncated !== undefined) set("truncated", patch.truncated ? 1 : 0);
    if (patch.collections !== undefined) set("collections_json", JSON.stringify(patch.collections));
    if (patch.artists !== undefined) set("artists_json", JSON.stringify(patch.artists));
    if (patch.total !== undefined) set("total", patch.total);
    if (patch.processed !== undefined) set("processed", patch.processed);
    this.#db.prepare(`UPDATE migration_jobs SET ${sets.join(", ")} WHERE id = ?`).run(...values, id);
  }

  replaceItems(jobId: string, items: NewMigrationItem[]) {
    this.#db.exec("BEGIN IMMEDIATE");
    try {
      this.#db.prepare("DELETE FROM migration_items WHERE job_id = ?").run(jobId);
      const insert = this.#db.prepare(`
        INSERT INTO migration_items (job_id, item_id, section, collection_id, position, source_key, source_json, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
      `);
      items.forEach((item, index) => insert.run(
        jobId, index + 1, item.section, item.collectionId ?? null, item.position, item.sourceKey, JSON.stringify(item.source)
      ));
      this.#db.exec("COMMIT");
    } catch (error) {
      this.#db.exec("ROLLBACK");
      throw error;
    }
    this.updateJob(jobId, { total: items.length, processed: 0 });
  }

  pendingItems(jobId: string) {
    return this.#items("WHERE job_id = ? AND status = 'pending' ORDER BY item_id", jobId);
  }

  allItems(jobId: string) {
    return this.#items("WHERE job_id = ? ORDER BY item_id", jobId);
  }

  getItem(jobId: string, itemId: number) {
    return this.#items("WHERE job_id = ? AND item_id = ?", jobId, itemId)[0];
  }

  /** Items sharing a source track within a job (same track liked and in playlists). */
  itemsBySourceKey(jobId: string, sourceKey: string) {
    return this.#items("WHERE job_id = ? AND source_key = ? ORDER BY item_id", jobId, sourceKey);
  }

  setItemMatch(
    jobId: string,
    itemId: number,
    result: {
      status: MigrationItemStatus;
      confidence: MatchConfidence | null;
      score: number | null;
      match?: MigrationItem["match"];
    }
  ) {
    this.#db.prepare(`
      UPDATE migration_items SET status = ?, confidence = ?, score = ?, match_json = ?
      WHERE job_id = ? AND item_id = ?
    `).run(
      result.status,
      result.confidence,
      result.score,
      result.match ? JSON.stringify(result.match) : null,
      jobId,
      itemId
    );
  }

  setLibraryTrackId(jobId: string, itemId: number, trackId: string) {
    this.#db.prepare("UPDATE migration_items SET library_track_id = ? WHERE job_id = ? AND item_id = ?")
      .run(trackId, jobId, itemId);
  }

  countProcessed(jobId: string) {
    const row = this.#db.prepare(`
      SELECT COUNT(*) AS count FROM migration_items WHERE job_id = ? AND status != 'pending'
    `).get(jobId) as { count: number };
    return Number(row.count);
  }

  seenKeys(userId: string, source: MigrationSource) {
    return new Set((this.#db.prepare(`
      SELECT source_key FROM migration_seen WHERE user_id = ? AND source = ?
    `).all(userId, source) as Array<{ source_key: string }>).map((row) => row.source_key));
  }

  markSeen(userId: string, source: MigrationSource, keys: Iterable<string>) {
    const now = this.now();
    const insert = this.#db.prepare(`
      INSERT OR IGNORE INTO migration_seen (user_id, source, source_key, seen_at) VALUES (?, ?, ?, ?)
    `);
    this.#db.exec("BEGIN IMMEDIATE");
    try {
      for (const key of keys) insert.run(userId, source, key, now);
      this.#db.prepare(`
        INSERT INTO migration_sync_state (user_id, source, last_synced_at) VALUES (?, ?, ?)
        ON CONFLICT(user_id, source) DO UPDATE SET last_synced_at = excluded.last_synced_at
      `).run(userId, source, now);
      this.#db.exec("COMMIT");
    } catch (error) {
      this.#db.exec("ROLLBACK");
      throw error;
    }
  }

  lastSyncedAt(userId: string, source: MigrationSource) {
    const row = this.#db.prepare(`
      SELECT last_synced_at FROM migration_sync_state WHERE user_id = ? AND source = ?
    `).get(userId, source) as { last_synced_at: number } | undefined;
    return row ? new Date(row.last_synced_at).toISOString() : undefined;
  }

  /** Aggregated match quality per source provider across all jobs. */
  metrics() {
    const rows = this.#db.prepare(`
      SELECT j.source AS source, j.target AS target, i.status AS status, i.confidence AS confidence, COUNT(*) AS count
      FROM migration_items i JOIN migration_jobs j ON j.id = i.job_id
      GROUP BY j.source, j.target, i.status, i.confidence
    `).all() as Array<{ source: string; target: string; status: string; confidence: string | null; count: number }>;
    const jobs = this.#db.prepare(`
      SELECT source, status, COUNT(*) AS count FROM migration_jobs GROUP BY source, status
    `).all() as Array<{ source: string; status: string; count: number }>;
    const bySource = new Map<string, ProviderMetrics>();
    const entry = (source: string) => {
      let value = bySource.get(source);
      if (!value) {
        value = { source, items: 0, exact: 0, high: 0, low: 0, none: 0, pending: 0, manual: 0, successRate: 0, jobs: {} };
        bySource.set(source, value);
      }
      return value;
    };
    for (const row of rows) {
      const metrics = entry(row.source);
      const count = Number(row.count);
      metrics.items += count;
      if (row.status === "pending") metrics.pending += count;
      else if (row.status === "confirmed" || row.status === "replaced") metrics.manual += count;
      else if (row.confidence === "exact" || row.confidence === "high" || row.confidence === "low") metrics[row.confidence] += count;
      else metrics.none += count;
    }
    for (const row of jobs) entry(row.source).jobs[row.status] = Number(row.count);
    for (const metrics of bySource.values()) {
      const decided = metrics.items - metrics.pending;
      metrics.successRate = decided ? round((metrics.exact + metrics.high + metrics.manual) / decided) : 0;
    }
    return [...bySource.values()];
  }

  #items(where: string, ...values: Array<string | number>) {
    return (this.#db.prepare(`SELECT * FROM migration_items ${where}`).all(...values) as unknown as ItemRow[])
      .map(itemFromRow);
  }
}

export interface ProviderMetrics {
  source: string;
  items: number;
  exact: number;
  high: number;
  low: number;
  none: number;
  pending: number;
  manual: number;
  successRate: number;
  jobs: Record<string, number>;
}

type JobRow = {
  id: string;
  user_id: string;
  source: MigrationSource;
  target: MigrationTarget;
  kind: MigrationKind;
  status: MigrationStatus;
  total: number;
  processed: number;
  error: string | null;
  warning: string | null;
  truncated: number;
  collections_json: string;
  artists_json: string;
  created_at: number;
  updated_at: number;
  completed_at: number | null;
};

type ItemRow = {
  job_id: string;
  item_id: number;
  section: MigrationSection;
  collection_id: string | null;
  position: number;
  source_key: string;
  source_json: string;
  status: MigrationItemStatus;
  confidence: MatchConfidence | null;
  score: number | null;
  match_json: string | null;
  library_track_id: string | null;
};

const round = (value: number) => Math.round(value * 1000) / 1000;

function jobFromRow(row: JobRow): MigrationJob {
  return {
    id: row.id,
    userId: row.user_id,
    source: row.source,
    target: row.target,
    kind: row.kind,
    status: row.status,
    total: Number(row.total),
    processed: Number(row.processed),
    ...(row.error ? { error: row.error } : {}),
    ...(row.warning ? { warning: row.warning } : {}),
    truncated: Boolean(row.truncated),
    collections: JSON.parse(row.collections_json) as MigrationCollection[],
    artists: JSON.parse(row.artists_json) as MigrationArtist[],
    createdAt: new Date(Number(row.created_at)).toISOString(),
    updatedAt: new Date(Number(row.updated_at)).toISOString(),
    ...(row.completed_at ? { completedAt: new Date(Number(row.completed_at)).toISOString() } : {})
  };
}

function itemFromRow(row: ItemRow): MigrationItem {
  return {
    jobId: row.job_id,
    itemId: Number(row.item_id),
    section: row.section,
    ...(row.collection_id ? { collectionId: row.collection_id } : {}),
    position: Number(row.position),
    sourceKey: row.source_key,
    source: JSON.parse(row.source_json) as ProviderTrack,
    status: row.status,
    confidence: row.confidence,
    score: row.score === null ? null : Number(row.score),
    ...(row.match_json ? { match: JSON.parse(row.match_json) as MigrationItem["match"] } : {}),
    ...(row.library_track_id ? { libraryTrackId: row.library_track_id } : {})
  };
}
