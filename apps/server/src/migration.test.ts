import assert from "node:assert/strict";
import { createServer, type Server } from "node:http";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import express from "express";
import { AccountStore } from "./account-store.js";
import { createMigrationRouter } from "./migration-api.js";
import { MigrationStore } from "./migration-store.js";
import { MigrationService, libraryTrack, type MigrationCatalog, type MigrationLibrarySource } from "./migration.js";
import { transliterate } from "./track-matcher.js";
import { ProviderGatewayError, type ImportedProviderLibrary, type ProviderTrack } from "./provider-gateway.js";

const directory = mkdtempSync(join(tmpdir(), "resonance-migration-"));
const cleanup: Array<() => void> = [];
after(() => {
  for (const close of cleanup) close();
  rmSync(directory, { recursive: true, force: true });
});

let counter = 0;
const spotifyTrack = (title: string, artist: string, seconds: number, isrc?: string): ProviderTrack => {
  counter += 1;
  return {
    id: `spotify:track:${counter}`,
    title,
    artist,
    durationMs: seconds * 1_000,
    externalUrl: `https://open.spotify.com/track/${counter}`,
    ...(isrc ? { isrc } : {})
  };
};

const yandexCatalog: ProviderTrack[] = [
  { id: "101", title: "Get Lucky", artist: "Daft Punk", durationMs: 369_000, externalUrl: "https://music.yandex.ru/track/101" },
  { id: "102", title: "Группа крови", artist: "Кино", durationMs: 286_000, externalUrl: "https://music.yandex.ru/track/102" },
  { id: "103", title: "Smells Like Teen Spirit", artist: "Nirvana", durationMs: 340_000, externalUrl: "https://music.yandex.ru/track/103" },
  { id: "104", title: "Let It Be", artist: "The Beatles", durationMs: 243_000, externalUrl: "https://music.yandex.ru/track/104" },
  { id: "105", title: "Halo", artist: "Beyonce", durationMs: 261_000, externalUrl: "https://music.yandex.ru/track/105" }
];

class FakeCatalog implements MigrationCatalog {
  calls = 0;
  failWith?: ProviderGatewayError;
  async search(_provider: string, query: string) {
    this.calls += 1;
    if (this.failWith) throw this.failWith;
    const words = query.toLowerCase().split(/\s+/);
    return yandexCatalog.filter((track) =>
      words.some((word) => word.length > 2 && transliterate(`${track.artist} ${track.title}`.toLowerCase()).includes(word))
    );
  }
}

class FakeLibrary implements MigrationLibrarySource {
  constructor(public library: ImportedProviderLibrary) {}
  async importLibrary() {
    return structuredClone(this.library);
  }
}

const baseLibrary = (): ImportedProviderLibrary => ({
  provider: "spotify",
  title: "Моя музыка",
  favorites: [
    spotifyTrack("Get Lucky", "Daft Punk", 369),
    spotifyTrack("Gruppa krovi", "Kino", 287),
    spotifyTrack("Smells Like Teen Spirit", "Nirvana", 301),
    spotifyTrack("Completely Unknown Song", "Nobody", 200)
  ],
  playlists: [{ externalId: "pl1", title: "Классика", tracks: [spotifyTrack("Let It Be - Remastered 2009", "The Beatles", 243)] }],
  albums: [{ externalId: "al1", title: "I Am... Sasha Fierce", artist: "Beyoncé", tracks: [spotifyTrack("Halo", "Beyoncé", 261)] }],
  artists: [{ externalId: "spotify:artist:1", name: "Daft Punk" }],
  truncated: false
});

async function setup(name: string) {
  const accounts = new AccountStore(join(directory, `${name}-account.sqlite`), "pepper");
  const store = new MigrationStore(join(directory, `${name}-migrations.sqlite`));
  cleanup.push(() => store.close(), () => accounts.close());
  const session = await accounts.register(`${name}@example.com`, "long-password-1", "test");
  const catalog = new FakeCatalog();
  const library = new FakeLibrary(baseLibrary());
  const logs: string[] = [];
  const service = new MigrationService(store, library, catalog, accounts, { retryDelayMs: 1, log: (line) => logs.push(line) });
  return { accounts, store, catalog, library, service, session, userId: session.user.id, logs };
}

test("full migration matches, reports and writes the account library", async () => {
  const { service, accounts, userId, logs } = await setup("full");
  const job = service.start(userId, { source: "spotify", target: "yandex" }, { source: { token: "s" } });
  await service.idle(job.id);
  const finished = service.job(userId, job.id);
  assert.equal(finished.status, "completed", finished.error);
  assert.equal(finished.total, 6);
  assert.equal(finished.progress, 100);

  const report = service.report(userId, job.id);
  assert.equal(report.summary.total, 6);
  assert.equal(report.summary.none, 1);
  assert.equal(report.unmatched.length, 1);
  assert.equal(report.unmatched[0]!.source.title, "Completely Unknown Song");
  assert.equal(report.lowConfidence.length, 1, "duration mismatch must stay low confidence");
  assert.equal(report.lowConfidence[0]!.source.title, "Smells Like Teen Spirit");
  assert.equal(report.summary.migrated, 4);
  assert.equal(report.summary.percent, 66.7);
  assert.equal(report.artists[0]!.name, "Daft Punk");
  assert.deepEqual(report.collections.map((collection) => collection.kind), ["playlist", "album"]);

  const stored = accounts.getLibrary(userId);
  assert.equal(stored.favorites.length, 4);
  const lucky = stored.favorites.find((track) => track.title === "Get Lucky")!;
  assert.equal(lucky.id, "yandex:101");
  assert.equal(lucky.preferredProvider, "yandex");
  assert.equal((lucky.sources as unknown[]).length, 2);
  // Low/none confidence keeps the original source so nothing is lost.
  assert.ok(stored.favorites.some((track) => track.id === report.unmatched[0]!.source.id));
  assert.equal(stored.playlists.length, 2);
  assert.ok(stored.playlists.some((playlist) => playlist.name === "I Am... Sasha Fierce · Beyoncé"));
  assert.ok(logs.some((line) => line.includes("providerSuccessRate=")));

  const metrics = service.metrics();
  assert.equal(metrics[0]!.source, "spotify");
  assert.equal(metrics[0]!.items, 6);
  assert.ok(metrics[0]!.successRate > 0.6);
});

test("manual confirm and replace update the report and the library", async () => {
  const { service, accounts, userId } = await setup("manual");
  const job = service.start(userId, { source: "spotify", target: "yandex" }, {});
  await service.idle(job.id);
  const report = service.report(userId, job.id);
  const low = report.lowConfidence[0]!;
  const confirmed = service.confirm(userId, job.id, low.itemId);
  assert.equal(confirmed.status, "confirmed");
  assert.ok(accounts.getLibrary(userId).favorites.some((track) => track.id === "yandex:103"));
  assert.ok(!accounts.getLibrary(userId).favorites.some((track) => track.id === low.source.id));

  const missing = report.unmatched[0]!;
  const candidates = await service.candidates(userId, job.id, missing.itemId, "Get Lucky");
  assert.equal(candidates[0]!.track.provider, "yandex");
  service.replace(userId, job.id, missing.itemId, {
    id: "999",
    title: "Completely Unknown Song",
    artist: "Nobody",
    externalUrl: "https://music.yandex.ru/track/999",
    provider: "yandex"
  });
  const after = service.report(userId, job.id);
  assert.equal(after.unmatched.length, 0);
  assert.equal(after.lowConfidence.length, 0);
  assert.equal(after.summary.manual, 2);
  assert.equal(after.summary.percent, 100);
  assert.ok(accounts.getLibrary(userId).favorites.some((track) => track.id === "yandex:999"));
});

test("resync only migrates likes added since the last sync", async () => {
  const { service, library, userId } = await setup("resync");
  const first = service.start(userId, { source: "spotify", target: "yandex" }, {});
  await service.idle(first.id);
  assert.ok(service.job(userId, first.id).lastSyncedAt);
  library.library.favorites.push(spotifyTrack("Halo", "Beyoncé", 261));
  const second = service.start(userId, { source: "spotify", target: "yandex", kind: "resync" }, {});
  await service.idle(second.id);
  const report = service.report(userId, second.id);
  assert.equal(service.job(userId, second.id).status, "completed");
  assert.equal(report.summary.total, 1);
  assert.equal(report.collections.length, 0);
});

test("a provider failure pauses the job and resume continues from pending items", async () => {
  const { service, catalog, userId } = await setup("resume");
  catalog.failWith = new ProviderGatewayError("INVALID_PROVIDER_TOKEN", "Токен Яндекса устарел", 401);
  const job = service.start(userId, { source: "spotify", target: "yandex" }, {});
  await service.idle(job.id);
  const paused = service.job(userId, job.id);
  assert.equal(paused.status, "paused");
  assert.equal(paused.error, "Токен Яндекса устарел");
  assert.equal(paused.total, 6, "fetched items are persisted");

  catalog.failWith = undefined;
  service.resume(userId, job.id, {});
  await service.idle(job.id);
  assert.equal(service.job(userId, job.id).status, "completed");
});

test("interrupted jobs are parked as paused after a restart", async () => {
  const { store, library, catalog, accounts, userId } = await setup("restart");
  const job = store.createJob({ id: "00000000-0000-4000-8000-000000000001", userId, source: "vk", target: "yandex", kind: "full" });
  store.updateJob(job.id, { status: "matching" });
  new MigrationService(store, library, catalog, accounts);
  assert.equal(store.getJob(job.id)!.status, "paused");
});

test("same provider migration is an exact identity match", async () => {
  const { service, userId } = await setup("identity");
  const job = service.start(userId, { source: "spotify", target: "spotify" }, {});
  await service.idle(job.id);
  const report = service.report(userId, job.id);
  assert.equal(report.summary.exact, 6);
  assert.equal(report.summary.percent, 100);
});

test("libraryTrack follows client id conventions", () => {
  const track = libraryTrack({
    jobId: "j",
    itemId: 1,
    section: "favorite",
    position: 0,
    sourceKey: "vk:1",
    source: { id: "vk:audio:1_2", title: "T", artist: "A", externalUrl: "https://vk.com/audio1_2" },
    status: "unmatched",
    confidence: "none",
    score: 0
  }, "vk");
  assert.equal(track?.id, "vk:audio:1_2");
  assert.equal(track?.preferredProvider, "vk");
});

test("migration HTTP API requires Resonance ID and exposes progress, report and admin metrics", async () => {
  const { service, accounts, session } = await setup("http");
  const app = express();
  app.use(express.json());
  app.use("/api/v1/migrations", createMigrationRouter(service, accounts, { adminToken: "admin-secret" }));
  const server: Server = createServer(app);
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  cleanup.unshift(() => server.close());
  const address = server.address();
  assert(address && typeof address === "object");
  const base = `http://127.0.0.1:${address.port}/api/v1/migrations`;
  const auth = { authorization: `Bearer ${session.accessToken}`, "content-type": "application/json" };

  assert.equal((await fetch(base)).status, 401);
  assert.equal((await fetch(`${base}/metrics`)).status, 404);

  const invalid = await fetch(base, { method: "POST", headers: auth, body: JSON.stringify({ source: "soundcloud", target: "yandex" }) });
  assert.equal(invalid.status, 400);

  const started = await fetch(base, {
    method: "POST",
    headers: { ...auth, "x-source-token": "spotify-token" },
    body: JSON.stringify({ source: "spotify", target: "yandex" })
  });
  assert.equal(started.status, 202);
  const { job } = await started.json() as { job: { id: string } };
  await service.idle(job.id);

  const progress = await (await fetch(`${base}/${job.id}`, { headers: auth })).json() as { job: { status: string; progress: number } };
  assert.equal(progress.job.status, "completed");
  assert.equal(progress.job.progress, 100);

  const report = await (await fetch(`${base}/${job.id}/report`, { headers: auth })).json() as {
    summary: { percent: number };
    unmatched: Array<{ itemId: number }>;
  };
  assert.equal(report.summary.percent, 66.7);

  const replaced = await fetch(`${base}/${job.id}/items/${report.unmatched[0]!.itemId}/replace`, {
    method: "POST",
    headers: auth,
    body: JSON.stringify({ track: { id: "555", title: "X", artist: "Y", externalUrl: "https://music.yandex.ru/track/555" } })
  });
  assert.equal(replaced.status, 200);
  assert.equal(((await replaced.json()) as { item: { status: string } }).item.status, "replaced");

  const notFound = await fetch(`${base}/00000000-0000-4000-8000-00000000ffff`, { headers: auth });
  assert.equal(notFound.status, 404);

  const metrics = await fetch(`${base}/metrics`, { headers: { "x-admin-token": "admin-secret" } });
  assert.equal(metrics.status, 200);
  const body = await metrics.json() as { providers: Array<{ source: string }> };
  assert.ok(body.providers.some((entry) => entry.source === "spotify"));
});
