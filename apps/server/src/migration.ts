import { createHash, randomUUID } from "node:crypto";
import { AccountError, type LibraryOperation } from "./account-store.js";
import {
  ProviderGatewayError,
  type ImportedProviderLibrary,
  type ProviderAccess,
  type ProviderName,
  type ProviderTrack
} from "./provider-gateway.js";
import {
  confidenceAtLeast,
  matchTrack,
  scoreTrackPair,
  searchQueryFor,
  stripTitleNoise,
  type MatchConfidence
} from "./track-matcher.js";
import {
  MigrationStore,
  type MigrationCollection,
  type MigrationItem,
  type MigrationJob,
  type MigrationKind,
  type MigrationSource,
  type MigrationTarget,
  type NewMigrationItem
} from "./migration-store.js";

export interface MigrationLibrarySource {
  importLibrary(provider: MigrationSource, access?: ProviderAccess): Promise<ImportedProviderLibrary>;
}

export interface MigrationCatalog {
  search(provider: ProviderName, query: string, limit: number, access?: ProviderAccess): Promise<ProviderTrack[]>;
}

export interface MigrationAccountLibrary {
  applyOperations(userId: string, operations: LibraryOperation[]): unknown;
}

export interface MigrationAccess {
  source?: ProviderAccess;
  target?: ProviderAccess;
}

export type MatchedTrack = ProviderTrack & { provider: ProviderName };

export class MigrationError extends Error {
  constructor(
    readonly code: "MIGRATION_NOT_FOUND" | "MIGRATION_ACTIVE" | "MIGRATION_STATE" | "ITEM_NOT_FOUND",
    message: string,
    readonly status: number
  ) {
    super(message);
  }
}

const SEARCH_LIMIT = 10;
const MATCH_CONCURRENCY = 4;
const OPERATION_CHUNK = 100;

export class MigrationService {
  readonly #running = new Map<string, Promise<void>>();

  constructor(
    private readonly store: MigrationStore,
    private readonly library: MigrationLibrarySource,
    private readonly catalog: MigrationCatalog,
    private readonly account: MigrationAccountLibrary,
    private readonly options: { retryDelayMs?: number; log?: (message: string) => void } = {}
  ) {
    store.pauseInterrupted();
  }

  start(
    userId: string,
    input: { source: MigrationSource; target: MigrationTarget; kind?: MigrationKind },
    access: MigrationAccess
  ) {
    const active = this.store.activeJob(userId);
    if (active) throw new MigrationError("MIGRATION_ACTIVE", "Перенос уже идёт", 409);
    const job = this.store.createJob({
      id: randomUUID(),
      userId,
      source: input.source,
      target: input.target,
      kind: input.kind ?? "full"
    });
    this.#launch(job, access);
    return this.store.getJob(job.id)!;
  }

  resume(userId: string, jobId: string, access: MigrationAccess) {
    const job = this.#ownedJob(userId, jobId);
    if (job.status !== "paused" && job.status !== "failed") {
      throw new MigrationError("MIGRATION_STATE", "Этот перенос нельзя продолжить", 409);
    }
    const active = this.store.activeJob(userId);
    if (active && active.id !== job.id) throw new MigrationError("MIGRATION_ACTIVE", "Перенос уже идёт", 409);
    this.store.updateJob(job.id, { status: "queued", error: undefined });
    this.#launch(this.store.getJob(job.id)!, access);
    return this.store.getJob(job.id)!;
  }

  list(userId: string) {
    return this.store.listJobs(userId).map((job) => this.#publicJob(job));
  }

  job(userId: string, jobId: string) {
    return this.#publicJob(this.#ownedJob(userId, jobId));
  }

  lastSync(userId: string, source: MigrationSource) {
    return this.store.lastSyncedAt(userId, source);
  }

  /** Resolves once a job's background run settles (used by tests and shutdown). */
  async idle(jobId: string) {
    await this.#running.get(jobId);
  }

  report(userId: string, jobId: string) {
    const job = this.#ownedJob(userId, jobId);
    const items = this.store.allItems(job.id);
    const titles = new Map(job.collections.map((collection) => [collection.id, collection.title]));
    const counts = { exact: 0, high: 0, low: 0, none: 0, manual: 0, pending: 0 };
    for (const item of items) {
      if (item.status === "pending") counts.pending += 1;
      else if (item.status === "confirmed" || item.status === "replaced") counts.manual += 1;
      else counts[item.confidence ?? "none"] += 1;
    }
    const migrated = counts.exact + counts.high + counts.manual;
    const view = (item: MigrationItem) => publicItem(item, titles);
    return {
      job: this.#publicJob(job),
      summary: {
        total: items.length,
        migrated,
        percent: items.length ? Math.round((migrated / items.length) * 1000) / 10 : 0,
        ...counts
      },
      lowConfidence: items.filter((item) => item.status === "matched" && item.confidence === "low").slice(0, 1_000).map(view),
      unmatched: items.filter((item) => item.status === "unmatched").slice(0, 1_000).map(view),
      collections: job.collections,
      artists: job.artists
    };
  }

  async candidates(userId: string, jobId: string, itemId: number, query: string | undefined, access?: ProviderAccess) {
    const job = this.#ownedJob(userId, jobId);
    const item = this.#item(job.id, itemId);
    const tracks = await this.catalog.search(job.target, query?.trim() || searchQueryFor(item.source), 20, access);
    return tracks
      .map((track) => ({ ...scoreTrackPair(item.source, track), track: { ...track, provider: job.target } }))
      .sort((left, right) => right.score - left.score);
  }

  confirm(userId: string, jobId: string, itemId: number) {
    const job = this.#ownedJob(userId, jobId);
    const item = this.#item(job.id, itemId);
    if (!item.match) throw new MigrationError("MIGRATION_STATE", "Для этого трека нет найденного совпадения", 409);
    return this.#applyManual(job, item, item.match, "confirmed");
  }

  replace(userId: string, jobId: string, itemId: number, track: MatchedTrack) {
    const job = this.#ownedJob(userId, jobId);
    const item = this.#item(job.id, itemId);
    return this.#applyManual(job, item, track, "replaced");
  }

  metrics() {
    return this.store.metrics();
  }

  #launch(job: MigrationJob, access: MigrationAccess) {
    const run = this.#run(job, access).finally(() => this.#running.delete(job.id));
    this.#running.set(job.id, run);
  }

  async #run(initial: MigrationJob, access: MigrationAccess) {
    const jobId = initial.id;
    try {
      // Yield so the HTTP response returns before provider work starts.
      await Promise.resolve();
      if (initial.total === 0 || this.store.allItems(jobId).length === 0) {
        this.store.updateJob(jobId, { status: "fetching" });
        const library = await this.library.importLibrary(initial.source, access.source);
        this.#storeFetchedLibrary(initial, library);
      }
      this.store.updateJob(jobId, { status: "matching" });
      await this.#matchPending(this.store.getJob(jobId)!, access.target);
      this.store.updateJob(jobId, { status: "saving", processed: this.store.countProcessed(jobId) });
      const warning = this.#saveToLibrary(this.store.getJob(jobId)!);
      const job = this.store.getJob(jobId)!;
      this.store.markSeen(
        job.userId,
        job.source,
        this.store.allItems(jobId).filter((item) => item.section === "favorite").map((item) => item.sourceKey)
      );
      this.store.updateJob(jobId, { status: "completed", ...(warning ? { warning } : {}), error: undefined });
      this.#logMetrics(job);
    } catch (error) {
      const message = errorMessage(error);
      const pausable = error instanceof ProviderGatewayError || error instanceof AccountError;
      this.store.updateJob(jobId, { status: pausable ? "paused" : "failed", error: message });
      this.#log(`Migration ${jobId} ${pausable ? "paused" : "failed"}: ${message}`);
    }
  }

  #storeFetchedLibrary(job: MigrationJob, library: ImportedProviderLibrary) {
    const items: NewMigrationItem[] = [];
    const key = (track: ProviderTrack) => `${job.source}:${track.id}`;
    const seen = job.kind === "resync" ? this.store.seenKeys(job.userId, job.source) : undefined;
    library.favorites.forEach((track, position) => {
      if (seen?.has(key(track))) return;
      items.push({ section: "favorite", position, sourceKey: key(track), source: track });
    });
    const collections: MigrationCollection[] = [];
    if (job.kind === "full") {
      const add = (kind: "playlist" | "album", playlists: ImportedProviderLibrary["playlists"]) => {
        for (const playlist of playlists) {
          const id = `${kind}:${playlist.externalId}`;
          if (collections.some((collection) => collection.id === id)) continue;
          collections.push({
            id,
            kind,
            title: playlist.title,
            ...(playlist.artist ? { artist: playlist.artist } : {}),
            ...(playlist.artworkUrl ? { artworkUrl: playlist.artworkUrl } : {}),
            trackCount: playlist.tracks.length
          });
          playlist.tracks.forEach((track, position) => {
            items.push({ section: kind, collectionId: id, position, sourceKey: key(track), source: track });
          });
        }
      };
      add("playlist", library.playlists);
      add("album", library.albums ?? []);
    }
    this.store.updateJob(job.id, {
      truncated: library.truncated,
      collections,
      artists: job.kind === "full" ? (library.artists ?? []).slice(0, 500) : []
    });
    this.store.replaceItems(job.id, items);
  }

  async #matchPending(job: MigrationJob, access?: ProviderAccess) {
    const pending = this.store.pendingItems(job.id);
    const groups = new Map<string, MigrationItem[]>();
    for (const item of pending) {
      const group = groups.get(item.sourceKey);
      if (group) group.push(item);
      else groups.set(item.sourceKey, [item]);
    }
    const queue = [...groups.values()];
    let processed = this.store.countProcessed(job.id);
    const worker = async () => {
      for (let group = queue.shift(); group; group = queue.shift()) {
        const result = await this.#matchOne(job, group[0]!.source, access);
        for (const item of group) {
          this.store.setItemMatch(job.id, item.itemId, {
            status: result.confidence === "none" ? "unmatched" : "matched",
            confidence: result.confidence,
            score: result.score,
            ...(result.candidate ? { match: result.candidate } : {})
          });
        }
        processed += group.length;
        this.store.updateJob(job.id, { processed });
      }
    };
    await Promise.all(Array.from({ length: Math.min(MATCH_CONCURRENCY, queue.length) }, worker));
  }

  async #matchOne(job: MigrationJob, source: ProviderTrack, access?: ProviderAccess): Promise<{
    confidence: MatchConfidence;
    score: number;
    candidate?: MatchedTrack;
  }> {
    if (job.target === job.source) {
      return { confidence: "exact", score: 1, candidate: { ...source, provider: job.target } };
    }
    const queries: string[] = [];
    if (source.isrc && job.target === "spotify") queries.push(`isrc:${source.isrc}`);
    queries.push(searchQueryFor(source));
    const titleOnly = stripTitleNoise(source.title).replace(/\s+/g, " ").trim();
    if (titleOnly && !queries.includes(titleOnly)) queries.push(titleOnly);
    let best: { confidence: MatchConfidence; score: number; candidate?: ProviderTrack } = { confidence: "none", score: 0 };
    for (const query of queries) {
      const candidates = await this.#search(job.target, query, access);
      const result = matchTrack(source, candidates);
      if (
        confidenceAtLeast(result.confidence, best.confidence) &&
        (result.confidence !== best.confidence || result.score > best.score)
      ) best = result;
      if (confidenceAtLeast(best.confidence, "high")) break;
    }
    return {
      confidence: best.confidence,
      score: best.score,
      ...(best.candidate ? { candidate: { ...best.candidate, provider: job.target } } : {})
    };
  }

  async #search(target: ProviderName, query: string, access?: ProviderAccess) {
    for (let attempt = 0; ; attempt += 1) {
      try {
        return await this.catalog.search(target, query, SEARCH_LIMIT, access);
      } catch (error) {
        if (error instanceof ProviderGatewayError && error.code === "TRACK_NOT_FOUND") return [];
        const retryable = error instanceof ProviderGatewayError &&
          ["PROVIDER_RATE_LIMITED", "UPSTREAM_ERROR", "UPSTREAM_TIMEOUT"].includes(error.code);
        if (!retryable || attempt >= 2) throw error;
        await delay((this.options.retryDelayMs ?? 1_500) * (attempt + 1));
      }
    }
  }

  /** Writes the migrated library into the Resonance ID account. Returns a warning when the quota was hit. */
  #saveToLibrary(job: MigrationJob) {
    const items = this.store.allItems(job.id);
    const operations: LibraryOperation[] = [];
    const trackIds: Array<[number, string]> = [];
    for (const item of items.filter((entry) => entry.section === "favorite")) {
      const track = libraryTrack(item, job.source);
      if (!track) continue;
      operations.push({ id: randomUUID(), type: "favoriteUpsert", track });
      trackIds.push([item.itemId, String(track.id)]);
    }
    const createdAt = new Date().toISOString();
    for (const collection of job.collections) {
      const playlistId = playlistIdFor(job, collection.id);
      const name = collection.kind === "album" && collection.artist
        ? `${collection.title} · ${collection.artist}`
        : collection.title;
      operations.push({ id: randomUUID(), type: "playlistUpsert", playlistId, name: name.slice(0, 120), createdAt });
      for (const item of items.filter((entry) => entry.collectionId === collection.id)) {
        const track = libraryTrack(item, job.source);
        if (!track) continue;
        operations.push({ id: randomUUID(), type: "playlistTrackUpsert", playlistId, track, position: item.position });
        trackIds.push([item.itemId, String(track.id)]);
      }
    }
    let warning: string | undefined;
    for (let offset = 0; offset < operations.length; offset += OPERATION_CHUNK) {
      try {
        this.account.applyOperations(job.userId, operations.slice(offset, offset + OPERATION_CHUNK));
      } catch (error) {
        if (error instanceof AccountError && error.code === "LIBRARY_LIMIT") {
          warning = "Медиатека Resonance заполнена: часть треков не поместилась.";
          break;
        }
        throw error;
      }
    }
    for (const [itemId, trackId] of trackIds) this.store.setLibraryTrackId(job.id, itemId, trackId);
    return warning;
  }

  #applyManual(job: MigrationJob, item: MigrationItem, track: MatchedTrack, status: "confirmed" | "replaced") {
    if (job.status !== "completed") {
      throw new MigrationError("MIGRATION_STATE", "Дождитесь окончания переноса", 409);
    }
    const siblings = this.store.itemsBySourceKey(job.id, item.sourceKey);
    const operations: LibraryOperation[] = [];
    for (const sibling of siblings) {
      const confidence = status === "confirmed" ? sibling.confidence : scoreTrackPair(sibling.source, track).confidence;
      this.store.setItemMatch(job.id, sibling.itemId, {
        status,
        confidence,
        score: status === "confirmed" ? sibling.score : scoreTrackPair(sibling.source, track).score,
        match: track
      });
      const updated = this.store.getItem(job.id, sibling.itemId)!;
      const libraryEntry = libraryTrack(updated, job.source);
      if (!libraryEntry) continue;
      const newId = String(libraryEntry.id);
      if (sibling.section === "favorite") {
        if (sibling.libraryTrackId && sibling.libraryTrackId !== newId) {
          operations.push({ id: randomUUID(), type: "favoriteDelete", trackId: sibling.libraryTrackId });
        }
        operations.push({ id: randomUUID(), type: "favoriteUpsert", track: libraryEntry });
      } else if (sibling.collectionId) {
        const playlistId = playlistIdFor(job, sibling.collectionId);
        if (sibling.libraryTrackId && sibling.libraryTrackId !== newId) {
          operations.push({ id: randomUUID(), type: "playlistTrackDelete", playlistId, trackId: sibling.libraryTrackId });
        }
        operations.push({ id: randomUUID(), type: "playlistTrackUpsert", playlistId, track: libraryEntry, position: sibling.position });
      }
      this.store.setLibraryTrackId(job.id, sibling.itemId, newId);
    }
    if (operations.length) {
      try {
        this.account.applyOperations(job.userId, operations);
      } catch (error) {
        // A playlist removed by the user in the meantime is not fatal for a match fix.
        if (!(error instanceof Error && /FOREIGN KEY/i.test(error.message))) throw error;
      }
    }
    const titles = new Map(job.collections.map((collection) => [collection.id, collection.title]));
    return publicItem(this.store.getItem(job.id, item.itemId)!, titles);
  }

  #ownedJob(userId: string, jobId: string) {
    const job = this.store.getJob(jobId);
    if (!job || job.userId !== userId) throw new MigrationError("MIGRATION_NOT_FOUND", "Перенос не найден", 404);
    return job;
  }

  #item(jobId: string, itemId: number) {
    const item = Number.isInteger(itemId) ? this.store.getItem(jobId, itemId) : undefined;
    if (!item) throw new MigrationError("ITEM_NOT_FOUND", "Трек не найден в отчёте", 404);
    return item;
  }

  #publicJob(job: MigrationJob) {
    const { userId: _userId, ...rest } = job;
    return {
      ...rest,
      progress: job.total ? Math.round((job.processed / job.total) * 1000) / 10 : 0,
      lastSyncedAt: this.store.lastSyncedAt(job.userId, job.source) ?? null
    };
  }

  #logMetrics(job: MigrationJob) {
    const metrics = this.store.metrics().find((entry) => entry.source === job.source);
    if (!metrics) return;
    this.#log(
      `Migration ${job.id} completed source=${job.source} target=${job.target} items=${job.total} ` +
      `providerSuccessRate=${metrics.successRate} exact=${metrics.exact} high=${metrics.high} low=${metrics.low} none=${metrics.none}`
    );
  }

  #log(message: string) {
    (this.options.log ?? console.log)(message);
  }
}

function publicItem(item: MigrationItem, titles: Map<string, string>) {
  return {
    itemId: item.itemId,
    section: item.section,
    ...(item.collectionId ? { collectionId: item.collectionId, collectionTitle: titles.get(item.collectionId) } : {}),
    position: item.position,
    status: item.status,
    confidence: item.confidence,
    score: item.score,
    source: item.source,
    match: item.match ?? null
  };
}

function playlistIdFor(job: MigrationJob, collectionId: string) {
  return `migr-${job.source}-${createHash("sha256").update(`${job.userId}:${collectionId}`).digest("hex").slice(0, 20)}`;
}

/** Same id convention as the Flutter client (backend_*_provider.dart). */
export function unifiedTrackId(provider: ProviderName, externalId: string) {
  return provider === "spotify" || provider === "vk" ? externalId : `${provider}:${externalId}`;
}

const isHttps = (value?: string) => {
  if (!value) return false;
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password;
  } catch {
    return false;
  }
};

/** Builds a UnifiedTrack-compatible JSON document for the account library. */
export function libraryTrack(item: MigrationItem, sourceProvider: MigrationSource): Record<string, unknown> | undefined {
  const trusted = item.status === "confirmed" || item.status === "replaced" ||
    (item.status === "matched" && (item.confidence === "exact" || item.confidence === "high"));
  const sourceTrack: MatchedTrack = { ...item.source, provider: sourceProvider };
  const primary = trusted && item.match ? item.match : sourceTrack;
  const sources = [primary, ...(primary === sourceTrack ? [] : [sourceTrack])]
    .filter((track, index, all) => all.findIndex((other) => other.provider === track.provider) === index)
    .filter((track) => isHttps(track.externalUrl))
    .map((track) => ({ provider: track.provider, externalId: track.id, externalUrl: track.externalUrl, metadata: {} }));
  if (!sources.length || !primary.title.trim() || !primary.artist.trim()) return undefined;
  return {
    id: unifiedTrackId(primary.provider, primary.id),
    title: primary.title.slice(0, 500),
    normalizedTitle: primary.title.trim().toLowerCase().slice(0, 500),
    artist: primary.artist.slice(0, 500),
    normalizedArtist: primary.artist.trim().toLowerCase().slice(0, 500),
    album: primary.album?.slice(0, 500) ?? null,
    duration: primary.durationMs != null && Number.isFinite(primary.durationMs) ? Math.max(0, Math.trunc(primary.durationMs)) : null,
    artworkUrl: isHttps(primary.artworkUrl) ? primary.artworkUrl : null,
    sources,
    preferredProvider: primary.provider
  };
}

function errorMessage(error: unknown) {
  if (error instanceof ProviderGatewayError || error instanceof AccountError) return error.message;
  console.error("Migration failed", error);
  return "Не удалось завершить перенос";
}

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
