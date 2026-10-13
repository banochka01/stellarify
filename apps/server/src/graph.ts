import express from "express";
import { z } from "zod";
import type { WaveTasteSignals } from "./account-store.js";
import { ApiError, CallBudget, clientKey, handle, optionalUser, parse, RateGate, requireUser, TtlCache, type Authenticate } from "./api-helpers.js";
import type { ProviderAccess, ProviderTrack } from "./provider-gateway.js";
import { splitArtists } from "./track-matcher.js";
import { normalize, type WaveItem, type WaveProviderName } from "./wave.js";

/**
 * Music Graph: artist ↔ artist relations.
 *
 * - `colisten`: how many different accounts listen to both artists. Built from
 *   anonymous per-account artist sets and only kept when at least
 *   `minUsers` accounts share the pair (k-anonymity), so no single listener's
 *   history can be read back from the graph.
 * - `feat`: the artists appear together in one credit ("A feat. B", "A & B");
 *   from history this also needs `minUsers` distinct accounts.
 * Names of nodes below the threshold are not exposed and weights are coarse.
 * - `similar`: provider fallback — artists that co-occur with the seed in
 *   provider search results. Used for new users and sparse parts of the graph.
 */

export type EdgeKind = "colisten" | "feat" | "similar";

export type GraphNeighbor = {
  artist: string;
  key: string;
  weight: number;
  /** Coarse strengths (powers of two for aggregated data), never exact listener counts. */
  kinds: Partial<Record<EdgeKind, number>>;
  listened?: boolean;
};

type Search = (provider: WaveProviderName, query: string, limit: number, access?: ProviderAccess) => Promise<ProviderTrack[]>;

export interface GraphSources {
  /** Anonymous artist sets, one per account (no identifiers). */
  artistSets(): string[][] | Promise<string[][]>;
  /** Provider search used as a fallback for sparse nodes. */
  search?: Search;
  fallbackProviders?: WaveProviderName[];
}

type Edge = Partial<Record<EdgeKind, number>>;

const kindWeight: Record<EdgeKind, number> = { colisten: 1, feat: 3, similar: 1.5 };
const FALLBACK_CALLS = 4;
const CHUNK = 200;

export const artistKey = (artist: string) => splitArtists(artist)[0] || normalize(artist);

/** Rounds an aggregate count down to a power of two so exact counts never leave the server. */
export const coarse = (count: number) => (count <= 0 ? 0 : 2 ** Math.floor(Math.log2(count)));

const yieldToLoop = () => new Promise<void>((resolve) => setImmediate(resolve));

export class MusicGraph {
  #edges = new Map<string, Map<string, Edge>>();
  #names = new Map<string, string>();
  /** Names learned from public provider data (fallback), kept across rebuilds. */
  readonly #publicNames = new Map<string, string>();
  readonly #fallback: TtlCache<Map<string, Edge>>;
  #builtAt = 0;
  #rebuilding?: Promise<void>;
  #timer?: NodeJS.Timeout;

  constructor(
    private readonly sources: GraphSources,
    private readonly options: { minUsers?: number; rebuildMs?: number; perUser?: number } = {},
    private readonly now: () => number = Date.now
  ) {
    this.#fallback = new TtlCache(12 * 60 * 60_000, 5_000, now);
  }

  get builtAt() { return this.#builtAt; }

  /** Background refresh; the timer never keeps the process alive. */
  start(intervalMs = this.options.rebuildMs ?? 30 * 60_000) {
    if (this.#timer) return;
    void this.rebuild().catch((error) => console.error("Music graph rebuild failed", error));
    this.#timer = setInterval(() => void this.rebuild().catch((error) => console.error("Music graph rebuild failed", error)), intervalMs);
    this.#timer.unref?.();
  }

  stop() {
    if (this.#timer) clearInterval(this.#timer);
    this.#timer = undefined;
  }

  /**
   * Rebuilds aggregated edges in chunks (yielding to the event loop between
   * them) and swaps the result in atomically; requests keep using the
   * previous graph meanwhile. Concurrent calls share one rebuild.
   */
  rebuild(): Promise<void> {
    this.#rebuilding ??= this.#build().finally(() => { this.#rebuilding = undefined; });
    return this.#rebuilding;
  }

  async #build() {
    const minUsers = this.options.minUsers ?? 3;
    const perUser = this.options.perUser ?? 30;
    const sets = await this.sources.artistSets();
    const pairs = new Map<string, number>();
    const feats = new Map<string, number>();
    const listeners = new Map<string, number>();
    const nameVotes = new Map<string, Map<string, number>>();
    for (let index = 0; index < sets.length; index += 1) {
      if (index > 0 && index % CHUNK === 0) await yieldToLoop();
      const keys = new Set<string>();
      const seenFeats = new Set<string>();
      const seenNodes = new Set<string>();
      for (const credit of sets[index]!) {
        const parts = splitArtists(credit);
        const primary = parts[0];
        if (!primary) continue;
        const votes = nameVotes.get(primary) ?? new Map<string, number>();
        const name = primaryCredit(credit);
        votes.set(name, (votes.get(name) ?? 0) + 1);
        nameVotes.set(primary, votes);
        if (keys.size < perUser) keys.add(primary);
        for (const part of parts) seenNodes.add(part);
        for (let i = 0; i < parts.length; i += 1) {
          for (let j = i + 1; j < parts.length; j += 1) {
            const id = pairId(parts[i]!, parts[j]!);
            if (id) seenFeats.add(id);
          }
        }
      }
      // Every count is "number of distinct accounts", so k-anonymity applies uniformly.
      for (const node of seenNodes) listeners.set(node, (listeners.get(node) ?? 0) + 1);
      for (const id of seenFeats) feats.set(id, (feats.get(id) ?? 0) + 1);
      const list = [...keys];
      for (let i = 0; i < list.length; i += 1) {
        for (let j = i + 1; j < list.length; j += 1) {
          const id = pairId(list[i]!, list[j]!);
          if (id) pairs.set(id, (pairs.get(id) ?? 0) + 1);
        }
      }
    }
    const edges = new Map<string, Map<string, Edge>>();
    for (const [id, count] of pairs) if (count >= minUsers) link(edges, id, "colisten", coarse(count));
    for (const [id, count] of feats) if (count >= minUsers) link(edges, id, "feat", coarse(count));
    const names = new Map<string, string>();
    for (const [key, votes] of nameVotes) {
      if ((listeners.get(key) ?? 0) < minUsers) continue;
      names.set(key, [...votes.entries()].sort((a, b) => b[1] - a[1])[0]![0]);
    }
    this.#edges = edges;
    this.#names = names;
    this.#builtAt = this.now();
  }

  #ensureFresh() {
    if (this.#rebuilding) return;
    if (!this.#builtAt || this.now() - this.#builtAt > (this.options.rebuildMs ?? 30 * 60_000)) {
      void this.rebuild().catch((error) => console.error("Music graph rebuild failed", error));
    }
  }

  displayName(key: string) {
    return this.#names.get(key) ?? this.#publicNames.get(key) ?? key;
  }

  /** Provider fallback: feat credits and artists co-occurring with the seed in search results. */
  async #providerEdges(key: string, label: string, budget?: CallBudget): Promise<Map<string, Edge>> {
    const search = this.sources.search;
    const providerList = (this.sources.fallbackProviders ?? ["soundcloud", "yandex"]).slice(0, 2);
    if (!search) return new Map();
    const cached = this.#fallback.peek(key);
    if (cached) return cached;
    if (budget && !budget.take(providerList.length * 2)) return new Map();
    return this.#fallback.get(key, async () => {
      const edges = new Map<string, Edge>();
      const queries = [label, `${label} feat`];
      const results = await Promise.all(providerList.flatMap((provider) =>
        queries.map((query) => search(provider, query, 20).catch(() => [] as ProviderTrack[]))));
      for (const track of results.flat()) {
        const parts = splitArtists(track.artist);
        const containsSeed = parts.includes(key);
        for (const part of parts) {
          if (!part || part === key) continue;
          if (!this.#publicNames.has(part) && this.#publicNames.size < 50_000) {
            this.#publicNames.set(part, part === parts[0] ? primaryCredit(track.artist) : part);
          }
          const edge = edges.get(part) ?? {};
          if (containsSeed) edge.feat = (edge.feat ?? 0) + 1;
          else edge.similar = (edge.similar ?? 0) + 1;
          edges.set(part, edge);
        }
      }
      return edges;
    });
  }

  async neighbors(artist: string, options: { limit?: number; listened?: Set<string>; fallback?: boolean; budget?: CallBudget } = {}): Promise<{ artist: string; key: string; neighbors: GraphNeighbor[]; source: "graph" | "providers" | "mixed" }> {
    this.#ensureFresh();
    const key = artistKey(artist);
    if (!key) throw new ApiError("INVALID_REQUEST", "Укажите артиста", 400);
    const limit = options.limit ?? 20;
    const merged = new Map<string, Edge>();
    for (const [to, edge] of this.#edges.get(key) ?? []) merged.set(to, { ...edge });
    let source: "graph" | "providers" | "mixed" = "graph";
    if ((options.fallback ?? true) && merged.size < 5) {
      const extra = await this.#providerEdges(key, artist.trim(), options.budget);
      if (extra.size) source = merged.size ? "mixed" : "providers";
      for (const [to, edge] of extra) {
        const current = merged.get(to) ?? {};
        for (const kind of Object.keys(edge) as EdgeKind[]) current[kind] = Math.max(current[kind] ?? 0, edge[kind] ?? 0);
        merged.set(to, current);
      }
    }
    const neighbors = [...merged.entries()].map(([to, kinds]): GraphNeighbor => ({
      artist: this.displayName(to),
      key: to,
      kinds,
      weight: Math.round((Object.entries(kinds) as Array<[EdgeKind, number]>)
        .reduce((total, [kind, value]) => total + kindWeight[kind] * Math.log2(1 + value), 0) * 100) / 100,
      ...(options.listened ? { listened: options.listened.has(to) } : {})
    })).sort((a, b) => b.weight - a.weight || a.key.localeCompare(b.key)).slice(0, limit);
    return { artist: this.#names.get(key) ?? artist.trim(), key, neighbors, source };
  }

  /**
   * Shortest strong path from A to B (BFS over the top neighbors of each
   * node, expanding at most `maxExpansions` nodes; provider fallback spends `budget`).
   */
  async path(from: string, to: string, options: { maxDepth?: number; maxExpansions?: number; listened?: Set<string>; budget?: CallBudget } = {}) {
    const start = artistKey(from);
    const goal = artistKey(to);
    if (!start || !goal) throw new ApiError("INVALID_REQUEST", "Укажите двух артистов", 400);
    const maxDepth = options.maxDepth ?? 5;
    const maxExpansions = options.maxExpansions ?? 40;
    const budget = options.budget ?? new CallBudget(FALLBACK_CALLS * 3);
    const parent = new Map<string, { from: string; kinds: Edge } | null>([[start, null]]);
    const label = new Map<string, string>([[start, from.trim()], [goal, to.trim()]]);
    let frontier = [start];
    let expansions = 0;
    let found = start === goal;
    for (let depth = 0; depth < maxDepth && !found && frontier.length; depth += 1) {
      const next: string[] = [];
      for (const node of frontier) {
        if (expansions >= maxExpansions) break;
        expansions += 1;
        const { neighbors } = await this.neighbors(label.get(node) ?? this.displayName(node), { limit: 12, budget });
        for (const neighbor of neighbors) {
          if (parent.has(neighbor.key)) continue;
          parent.set(neighbor.key, { from: node, kinds: neighbor.kinds });
          label.set(neighbor.key, neighbor.artist);
          if (neighbor.key === goal) { found = true; break; }
          next.push(neighbor.key);
        }
        if (found) break;
      }
      frontier = next;
    }
    const chain: Array<{ key: string; via: Edge | null }> = [];
    if (found) {
      for (let cursor: string | undefined = goal; cursor !== undefined;) {
        const link: { from: string; kinds: Edge } | null | undefined = parent.get(cursor);
        chain.unshift({ key: cursor, via: link?.kinds ?? null });
        cursor = link?.from;
      }
    } else {
      chain.push({ key: start, via: null }, { key: goal, via: null });
    }
    const nodes = chain.map((entry) => ({
      artist: label.get(entry.key) ?? this.displayName(entry.key),
      key: entry.key,
      via: entry.via ? (Object.keys(entry.via) as EdgeKind[]) : [],
      ...(options.listened ? { listened: options.listened.has(entry.key) } : {})
    }));
    return { found, nodes, queries: radioQueries(nodes) };
  }
}

/** Turns a path into an ordered list of search queries: each artist, plus the bridge between feat neighbours. */
export function radioQueries(nodes: Array<{ artist: string; via: EdgeKind[] }>, perArtist = 2) {
  const queries: Array<{ artist: string; query: string }> = [];
  nodes.forEach((node, index) => {
    const previous = nodes[index - 1];
    if (previous && node.via.includes("feat")) queries.push({ artist: node.artist, query: `${previous.artist} ${node.artist}` });
    queries.push({ artist: node.artist, query: node.artist });
    if (perArtist > 1) queries.push({ artist: node.artist, query: `${node.artist} best` });
  });
  return queries;
}

function link(edges: Map<string, Map<string, Edge>>, id: string, kind: EdgeKind, value: number) {
  const [a, b] = id.split("\u0000") as [string, string];
  for (const [from, to] of [[a, b], [b, a]] as const) {
    const map = edges.get(from) ?? new Map<string, Edge>();
    const edge = map.get(to) ?? {};
    edge[kind] = Math.max(edge[kind] ?? 0, value);
    map.set(to, edge);
    edges.set(from, map);
  }
}

const pairId = (a: string, b: string) => (a === b || !a || !b ? undefined : a < b ? `${a}\u0000${b}` : `${b}\u0000${a}`);

const primaryCredit = (credit: string) => credit.split(/\s*(?:,|;|\/|\s&\s|\sfeat\.?\s|\sft\.?\s)\s*/iu)[0]?.trim() || credit;

export function listenedArtists(signals: WaveTasteSignals) {
  const keys = new Set<string>();
  for (const item of [...signals.listening.filter((entry) => entry.type !== "skipped" && entry.type !== "disliked"), ...signals.favorites, ...signals.playlistTracks]) {
    const key = artistKey(item.artist);
    if (key) keys.add(key);
  }
  return keys;
}

const nameSchema = z.string().trim().min(1).max(200);
const providerSchema = z.enum(["soundcloud", "yandex", "spotify", "vk"]);

export function createGraphRouter(
  graph: MusicGraph,
  options: {
    authenticate: Authenticate;
    taste: (userId: string) => WaveTasteSignals;
    search?: Search;
    access?: (request: express.Request) => Partial<Record<WaveProviderName, ProviderAccess>>;
  }
) {
  const router = express.Router();
  const gate = new RateGate(60, 60_000);
  const pathGate = new RateGate(6, 60_000);
  const listenedFor = (request: express.Request) => {
    const userId = optionalUser(options.authenticate, request);
    return userId ? listenedArtists(options.taste(userId)) : undefined;
  };
  router.use((request, response, next) => {
    response.setHeader("cache-control", "private, no-store");
    try {
      gate.check(clientKey(request));
      next();
    } catch (error) {
      handle(() => { throw error; })(request, response);
    }
  });

  router.get("/artist", handle(async (request) => {
    const query = parse(z.object({ name: nameSchema, limit: z.coerce.number().int().min(1).max(50).default(20) }), request.query, "Укажите артиста");
    return graph.neighbors(query.name, { limit: query.limit, listened: listenedFor(request), budget: new CallBudget(4) });
  }));

  router.get("/path", handle(async (request) => {
    const query = parse(z.object({
      from: nameSchema,
      to: nameSchema,
      tracks: z.enum(["0", "1", "true", "false"]).default("0"),
      provider: providerSchema.default("soundcloud")
    }), request.query, "Укажите двух артистов");
    // Path radio fans out to providers: account only, strict per-user limit, one call budget per request.
    const userId = requireUser(options.authenticate, request);
    pathGate.check(userId);
    const pathBudget = new CallBudget(12);
    const result = await graph.path(query.from, query.to, { listened: listenedArtists(options.taste(userId)), budget: pathBudget });
    // Total per request: at most 20 provider calls (path fallback + track lookups).
    const budget = new CallBudget(20 - (12 - pathBudget.remaining));
    if (!["1", "true"].includes(query.tracks) || !options.search) return result;
    const access = options.access?.(request)[query.provider];
    const seen = new Set<string>();
    const tracks: WaveItem[] = [];
    for (const entry of result.queries.slice(0, 16)) {
      if (!budget.take()) break;
      const found = await options.search(query.provider, entry.query, 3, access).catch(() => [] as ProviderTrack[]);
      let taken = 0;
      for (const [rank, track] of found.entries()) {
        const key = `${track.artist}::${track.title}`.toLowerCase();
        if (seen.has(key) || taken >= 2) continue;
        seen.add(key);
        taken += 1;
        tracks.push({ ...track, provider: query.provider, lane: "adjacent", score: 1 - rank * .1, reason: `По пути: ${entry.artist}` });
      }
    }
    return { ...result, tracks };
  }));

  /** Personal layer: your artists, and graph neighbours you have not listened to yet. */
  router.get("/me", handle(async (request) => {
    const userId = options.authenticate(request);
    if (!userId) throw new ApiError("AUTH_REQUIRED", "Войдите в аккаунт", 401);
    const signals = options.taste(userId);
    const listened = listenedArtists(signals);
    const counts = new Map<string, { name: string; count: number }>();
    for (const item of [...signals.listening, ...signals.favorites, ...signals.playlistTracks]) {
      const key = artistKey(item.artist);
      if (!key) continue;
      const entry = counts.get(key) ?? { name: primaryCredit(item.artist), count: 0 };
      entry.count += 1;
      counts.set(key, entry);
    }
    const top = [...counts.entries()].sort((a, b) => b[1].count - a[1].count).slice(0, 5);
    const budget = new CallBudget(8);
    const unexplored = new Map<string, GraphNeighbor & { from: string }>();
    for (const [, entry] of top) {
      const { neighbors } = await graph.neighbors(entry.name, { limit: 10, listened, fallback: listened.size < 10, budget });
      for (const neighbor of neighbors) {
        if (neighbor.listened || unexplored.has(neighbor.key)) continue;
        unexplored.set(neighbor.key, { ...neighbor, from: entry.name });
      }
    }
    return {
      listened: top.map(([key, entry]) => ({ artist: entry.name, key, plays: entry.count })),
      unexplored: [...unexplored.values()].sort((a, b) => b.weight - a.weight).slice(0, 20),
      newUser: listened.size < 3
    };
  }));
  return router;
}
