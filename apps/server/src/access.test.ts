import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import express from "express";
import {
  AccessControl,
  createLegacyAccessRouter,
  freeAccessSnapshot
} from "./access.js";
import { AccountStore } from "./account-store.js";

test("free access enables every product capability without an expiry paywall", () => {
  const access = freeAccessSnapshot();
  assert.equal(access.tier, "free");
  assert.equal(access.accessModel, "free");
  assert.deepEqual(access.providers, ["soundcloud", "yandex", "spotify", "vk"]);
  assert.ok(Object.values(access.capabilities).every((enabled) => enabled || enabled === false));
  assert.equal(access.capabilities["family.manage"], false);
  assert.ok(
    Object.entries(access.capabilities)
      .filter(([name]) => name !== "family.manage")
      .every(([, enabled]) => enabled)
  );
});

test("legacy access endpoints grant free access and still validate account tokens", async (t) => {
  const directory = mkdtempSync(join(tmpdir(), "resonance-free-access-"));
  const accounts = new AccountStore(join(directory, "test.sqlite"));
  const access = new AccessControl(accounts);
  const app = express();
  app.use(express.json());
  app.use("/subscription", createLegacyAccessRouter(access));
  const server = createServer(app);
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(async () => {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    accounts.close();
    rmSync(directory, { recursive: true, force: true });
  });

  const address = server.address();
  assert(address && typeof address !== "string");
  const base = `http://127.0.0.1:${address.port}`;
  const request = (path: string, init?: RequestInit) => fetch(base + path, init);
  const guestToken = randomBytes(32).toString("base64url");
  const guest = await request("/subscription/guest", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ token: guestToken })
  });
  assert.equal(guest.status, 200);
  assert.equal((await guest.json()).subscription.tier, "free");
  assert.equal((await request("/subscription/status")).status, 200);
  assert.equal((await request("/subscription/status", {
    headers: { authorization: `Bearer ${"x".repeat(40)}` }
  })).status, 401);

  const session = await accounts.register(
    "free@example.com",
    "this is a secure password",
    "test"
  );
  const redeemed = await request("/subscription/redeem", {
    method: "POST",
    headers: {
      authorization: `Bearer ${session.accessToken}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({ code: "legacy-client-compatibility" })
  });
  assert.equal(redeemed.status, 200);
  assert.equal((await redeemed.json()).subscription.accessModel, "free");
});
