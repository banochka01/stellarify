import assert from "node:assert/strict";
import { test } from "node:test";
import { openSqlite } from "./api-helpers.js";
import { applyFlagOverrides, createPlatformRouter, defaultFeatureFlags, enabledFlags } from "./platform.js";
import { SocialStore } from "./social-store.js";
import { headerAuth, serveRouter, strictHeaderAuth } from "./test-http.js";

test("flags depend on channel, env requirements, overrides and rollout", () => {
  const flags = applyFlagOverrides(defaultFeatureFlags({}), "social.blend=beta");
  assert.ok(enabledFlags(defaultFeatureFlags({}), "stable").includes("social.blend"), "5.0 ships Blend to stable");
  const stable = enabledFlags(flags, "stable");
  const beta = enabledFlags(flags, "beta");
  assert.ok(stable.includes("social.profiles"));
  assert.ok(!stable.includes("social.blend"));
  assert.ok(beta.includes("social.blend"));
  assert.ok(!beta.includes("artists.setlists"), "needs SETLISTFM_API_KEY");
  assert.ok(enabledFlags(defaultFeatureFlags({ SETLISTFM_API_KEY: "k" }), "stable").includes("artists.setlists"));

  const overridden = applyFlagOverrides(flags, "social.blend=stable, social.feed=off, library.cleanup=beta:0, bogus");
  assert.ok(enabledFlags(overridden, "stable").includes("social.blend"));
  assert.ok(!enabledFlags(overridden, "beta").includes("social.feed"));
  assert.ok(!enabledFlags(overridden, "beta", "user").includes("library.cleanup"));
  const half = applyFlagOverrides(flags, "social.blend=beta:50");
  const users = Array.from({ length: 200 }, (_, index) => `user-${index}`);
  const share = users.filter((user) => enabledFlags(half, "beta", user).includes("social.blend")).length;
  assert.ok(share > 60 && share < 140, String(share));
  assert.equal(enabledFlags(half, "beta", "user-1").includes("social.blend"), enabledFlags(half, "beta", "user-1").includes("social.blend"));
});

test("expired token on public endpoints is anonymous; GET /channel is rate limited", async () => {
  const api = await serveRouter("/api/v1", createPlatformRouter(new SocialStore(openSqlite(":memory:")), strictHeaderAuth, defaultFeatureFlags({})));
  try {
    const features = await api.call("GET", "/features?channel=beta", "bad");
    assert.equal(features.status, 200);
    assert.equal(features.body.channel, "beta");
    assert.equal((await api.call("GET", "/channel", "bad")).status, 401);
    let limited = false;
    for (let index = 0; index < 125 && !limited; index += 1) limited = (await api.call("GET", "/channel", "u9")).status === 429;
    assert.ok(limited);
  } finally {
    await api.close();
  }
});

test("changelog, features and account channel", async () => {
  const api = await serveRouter("/api/v1", createPlatformRouter(new SocialStore(openSqlite(":memory:")), headerAuth, defaultFeatureFlags({})));
  try {
    const stable = await api.call("GET", "/changelog");
    assert.equal(stable.status, 200);
    assert.ok(stable.body.entries.every((entry: { channel: string }) => entry.channel === "stable"));
    const beta = await api.call("GET", "/changelog?channel=beta");
    assert.ok(beta.body.entries.length >= stable.body.entries.length);
    assert.equal((await api.call("GET", "/changelog?channel=nightly")).status, 400);

    assert.equal((await api.call("GET", "/features")).body.channel, "stable");
    assert.ok((await api.call("GET", "/features?channel=beta")).body.flags.includes("social.blend"));

    assert.equal((await api.call("GET", "/channel")).status, 401);
    assert.equal((await api.call("GET", "/channel", "u1")).body.channel, "stable");
    const switched = await api.call("PUT", "/channel", "u1", { channel: "beta" });
    assert.equal(switched.body.channel, "beta");
    assert.ok(switched.body.flags.includes("social.blend"));
    // The stored channel wins over the query for signed-in clients.
    assert.equal((await api.call("GET", "/features?channel=stable", "u1")).body.channel, "beta");
    assert.equal((await api.call("PUT", "/channel", "u1", { channel: "alpha" })).status, 400);
  } finally {
    await api.close();
  }
});
