import assert from "node:assert/strict";
import { createServer, type Server } from "node:http";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, test } from "node:test";
import express from "express";
import { createAccountRouter } from "./account-api.js";
import { AccountStore } from "./account-store.js";
import type { MailMessage, Mailer } from "./mailer.js";

const directory = mkdtempSync(join(tmpdir(), "resonance-account-mail-"));
const store = new AccountStore(join(directory, "account.sqlite"), "test-pepper");
const outbox: MailMessage[] = [];
const mailer: Mailer = { enabled: true, async send(message) { outbox.push(message); } };
let server: Server;
let baseUrl: string;

before(async () => {
  const app = express();
  app.use(express.json({ limit: "32kb" }));
  app.use("/api/v1/account", createAccountRouter(store, mailer));
  server = createServer(app);
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  assert(address && typeof address === "object");
  baseUrl = `http://127.0.0.1:${address.port}/api/v1/account`;
});

after(async () => {
  await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  store.close();
  rmSync(directory, { recursive: true, force: true });
});

const request = async (path: string, body?: unknown, token?: string) => {
  const response = await fetch(`${baseUrl}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body ?? {})
  });
  const text = await response.text();
  return { response, body: text ? JSON.parse(text) : undefined };
};

const nextMail = async (to: string) => {
  for (let i = 0; i < 50; i += 1) {
    const index = outbox.findIndex((message) => message.to === to);
    if (index >= 0) return outbox.splice(index, 1)[0]!;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`no mail for ${to}`);
};

const codeOf = (message: MailMessage) => message.text.match(/\b(\d{6})\b/u)?.[1] ?? "";

test("registration sends a verification code that verifies the address", async () => {
  const registered = await request("/register", { email: "verify@example.com", password: "correct horse battery" });
  assert.equal(registered.response.status, 201);
  assert.equal(registered.body.user.emailVerified, false);
  const mail = await nextMail("verify@example.com");
  const token = registered.body.accessToken as string;

  const wrong = await request("/email/verify", { code: codeOf(mail) === "000000" ? "111111" : "000000" }, token);
  assert.equal(wrong.response.status, 400);
  const verified = await request("/email/verify", { code: codeOf(mail) }, token);
  assert.equal(verified.response.status, 200);
  assert.equal(verified.body.user.emailVerified, true);
  const reused = await request("/email/verify", { code: codeOf(mail) }, token);
  assert.equal(reused.response.status, 400);
});

test("password reset by code revokes sessions and is indistinguishable for unknown mail", async () => {
  const registered = await request("/register", { email: "reset@example.com", password: "old password 123" });
  await nextMail("reset@example.com");

  const unknown = await request("/password/forgot", { email: "nobody@example.com" });
  const known = await request("/password/forgot", { email: "Reset@Example.com" });
  assert.equal(unknown.response.status, 202);
  assert.deepEqual(unknown.body, known.body);
  const mail = await nextMail("reset@example.com");
  assert.equal(outbox.some((message) => message.to === "nobody@example.com"), false);

  const bad = await request("/password/reset", { email: "reset@example.com", code: "12345", password: "new password 456" });
  assert.equal(bad.response.status, 400);
  const reset = await request("/password/reset", { email: "reset@example.com", code: codeOf(mail), password: "new password 456" });
  assert.equal(reset.response.status, 200);
  assert.equal(reset.body.user.emailVerified, true);
  assert.match((await nextMail("reset@example.com")).subject, /изменён/u);

  const oldRefresh = await request("/refresh", { refreshToken: registered.body.refreshToken });
  assert.equal(oldRefresh.response.status, 401);
  const oldLogin = await request("/login", { email: "reset@example.com", password: "old password 123" });
  assert.equal(oldLogin.response.status, 401);
  const newLogin = await request("/login", { email: "reset@example.com", password: "new password 456" });
  assert.equal(newLogin.response.status, 200);
  const replay = await request("/password/reset", { email: "reset@example.com", code: codeOf(mail), password: "another pass 789" });
  assert.equal(replay.response.status, 400);
});

test("reset code locks after five wrong attempts", async () => {
  await request("/register", { email: "lock@example.com", password: "lock password 1" });
  await nextMail("lock@example.com");
  await request("/password/forgot", { email: "lock@example.com" });
  const code = codeOf(await nextMail("lock@example.com"));
  const wrongCode = code === "999999" ? "999998" : "999999";
  for (let i = 0; i < 5; i += 1) {
    await request("/password/reset", { email: "lock@example.com", code: wrongCode, password: "lock password 2" });
  }
  const locked = await request("/password/reset", { email: "lock@example.com", code, password: "lock password 2" });
  assert.equal(locked.response.status, 400);
});

test("changing the password requires the current one and signs out other devices", async () => {
  const first = await request("/register", { email: "change@example.com", password: "first password 1" });
  await nextMail("change@example.com");
  const other = await request("/login", { email: "change@example.com", password: "first password 1", deviceName: "Phone" });

  const wrong = await request("/password/change", { currentPassword: "not it at all", password: "second password 2" }, first.body.accessToken);
  assert.equal(wrong.response.status, 401);
  const changed = await request("/password/change", { currentPassword: "first password 1", password: "second password 2" }, first.body.accessToken);
  assert.equal(changed.response.status, 200);
  assert.ok(changed.body.accessToken);
  await nextMail("change@example.com");

  const stale = await request("/refresh", { refreshToken: other.body.refreshToken });
  assert.equal(stale.response.status, 401);
  const fresh = await fetch(`${baseUrl}/me`, { headers: { authorization: `Bearer ${changed.body.accessToken}` } });
  assert.equal(fresh.status, 200);
});
