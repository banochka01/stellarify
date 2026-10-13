import assert from "node:assert/strict";
import { test } from "node:test";
import { createSetlistRouter, SetlistService } from "./setlists.js";
import { serveRouter } from "./test-http.js";

test("setlists are disabled without SETLISTFM_API_KEY", async () => {
  const api = await serveRouter("/api/v1/setlists", createSetlistRouter(new SetlistService("")));
  try {
    assert.deepEqual((await api.call("GET", "/?artist=Muse")).body, { available: false, setlists: [] });
    assert.equal((await api.call("GET", "/")).status, 400);
  } finally {
    await api.close();
  }
});

test("setlist.fm responses become search queries, cached", async () => {
  let calls = 0;
  const service = new SetlistService("key", (async (url: URL, init?: RequestInit) => {
    calls += 1;
    assert.equal((init?.headers as Record<string, string>)["x-api-key"], "key");
    assert.equal(url.searchParams.get("artistName"), "Muse");
    return new Response(JSON.stringify({
      setlist: [{
        id: "abc", eventDate: "23-08-2026", url: "https://www.setlist.fm/x",
        artist: { name: "Muse" }, tour: { name: "Will of the People" },
        venue: { name: "Stadion", city: { name: "Warsaw", country: { name: "Poland" } } },
        sets: { set: [{ song: [{ name: "Uprising" }, { name: "Feeling Good", cover: { name: "Nina Simone" } }, { name: "" }] }] }
      }, { id: "empty", eventDate: "01-01-2026", artist: { name: "Muse" }, sets: { set: [] } }]
    }));
  }) as typeof fetch);
  const result = await service.recent("Muse");
  assert.equal(result.available, true);
  assert.equal(result.setlists.length, 1);
  const setlist = result.setlists[0]!;
  assert.equal(setlist.eventDate, "2026-08-23");
  assert.equal(setlist.city, "Warsaw");
  assert.deepEqual(setlist.tracks.map((track) => track.query), ["Muse Uprising", "Nina Simone Feeling Good"]);
  await service.recent("muse");
  assert.equal(calls, 1);
});

test("cache-control is public only for real answers", async () => {
  const off = await serveRouter("/s", createSetlistRouter(new SetlistService("")));
  const on = await serveRouter("/s", createSetlistRouter(new SetlistService("key", (async () => new Response(JSON.stringify({ setlist: [] }))) as typeof fetch)));
  try {
    assert.equal((await off.call("GET", "/?artist=Muse")).headers.get("cache-control"), "no-store");
    assert.equal((await on.call("GET", "/?artist=Muse")).headers.get("cache-control"), "public, max-age=3600");
  } finally {
    await off.close();
    await on.close();
  }
});
