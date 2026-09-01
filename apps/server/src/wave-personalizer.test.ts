import assert from "node:assert/strict";
import test from "node:test";
import { AccountStore } from "./account-store.js";
import { WavePersonalizer } from "./wave-personalizer.js";

const favorite = {
  id: "favorite-1",
  title: "Night Drive",
  normalizedTitle: "night drive",
  artist: "Favorite Artist",
  normalizedArtist: "favorite artist",
  album: "City Lights",
  duration: 180_000,
  artworkUrl: null,
  sources: [],
  preferredProvider: "soundcloud"
};

async function accountWithTaste() {
  const store = new AccountStore(":memory:");
  const session = await store.register("wave@example.com", "a secure wave password", "Tests");
  store.applyOperations(session.user.id, [{
    id: "e95702e0-507f-4d10-a052-051e1b16f5a0",
    type: "favoriteUpsert",
    track: favorite
  }]);
  store.recordWaveFeedback(session.user.id, {
    eventId: "34ecdc54-a508-41d6-a3eb-da710c48a45c",
    type: "finished",
    provider: "soundcloud",
    trackId: "played-1",
    playedDurationMs: 170_000
  }, { title: "Played", artist: "Played Artist" });
  return { store, userId: session.user.id };
}

test("builds a deterministic account profile without an AgentRouter key", async () => {
  const { store, userId } = await accountWithTaste();
  try {
    const profile = await new WavePersonalizer(store).personalize(userId);
    assert.equal(profile.source, "deterministic");
    assert.equal(profile.seedQueries[0], "Favorite Artist");
    assert.ok(profile.artistWeights["favorite artist"]! > 0);
    assert.ok(profile.artistWeights["played artist"]! > 0);
  } finally {
    store.close();
  }
});

test("uses AgentRouter JSON parameters, minimizes data, and caches unchanged taste", async () => {
  const { store, userId } = await accountWithTaste();
  let calls = 0;
  let requestBody = "";
  const request: typeof fetch = async (_input, init) => {
    calls++;
    requestBody = String(init?.body);
    return Response.json({ choices: [{ message: { content: "```json\n{\"seedQueries\":[\"dream pop\"],\"artistPreferences\":[{\"artist\":\"Favorite Artist\",\"weight\":0.8}],\"discoveryDelta\":0.1}\n```" } }] });
  };
  try {
    const personalizer = new WavePersonalizer(store, { apiKey: "test-secret", model: "glm-5.2" }, request);
    const first = await personalizer.personalize(userId);
    const second = await personalizer.personalize(userId);
    assert.equal(first.source, "agentrouter");
    assert.equal(first.seedQueries[0], "dream pop");
    assert.equal(first.discoveryDelta, .1);
    assert.deepEqual(second, first);
    assert.equal(calls, 1);
    assert.match(requestBody, /Favorite Artist/u);
    assert.doesNotMatch(requestBody, new RegExp(userId, "u"));
    assert.doesNotMatch(requestBody, /test-secret/u);
    assert.doesNotMatch(requestBody, /externalUrl|playlistName|providerToken/u);
  } finally {
    store.close();
  }
});

test("falls back locally when AgentRouter fails", async () => {
  const { store, userId } = await accountWithTaste();
  const request: typeof fetch = async () => new Response("unavailable", { status: 503 });
  try {
    const profile = await new WavePersonalizer(store, { apiKey: "test-secret" }, request).personalize(userId);
    assert.equal(profile.source, "deterministic");
    assert.ok(profile.seedQueries.length > 0);
  } finally {
    store.close();
  }
});
