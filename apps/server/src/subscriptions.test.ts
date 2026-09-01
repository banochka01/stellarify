import assert from "node:assert/strict";
import { randomBytes, randomUUID } from "node:crypto";
import { mkdtempSync, rmSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { test } from "node:test";
import { Response } from "undici";
import { SubscriptionStore, SubscriptionError, dayMs, type Plan } from "./subscriptions.js";
import { botConfiguration, processPromoCommand, runPromoBot } from "./promo-bot.js";

function fixture(t: import("node:test").TestContext) {
  const directory = mkdtempSync(join(tmpdir(), "resonance-subscription-"));
  const path = join(directory, "test.sqlite");
  let now = Date.now();
  const store = new SubscriptionStore(path, () => now);
  t.after(() => { store.close(); rmSync(directory, { recursive: true, force: true }); });
  const issue = (plan: Plan, days: number, validity = 90) => {
    const code = randomBytes(24).toString("hex");
    const id = store.createPromo(plan, days, validity, "test-admin", randomUUID(), code);
    return { code, id };
  };
  return { store, issue, path, advance: (days: number) => { now += days * dayMs; } };
}
const fails = (code: string) => (e: unknown) => e instanceof SubscriptionError && e.code === code;

test("guest expires exactly at 24h; retries and registration do not reset; bound guest cannot be reused", t => {
  const { store, advance } = fixture(t);
  const token = randomBytes(32).toString("base64url");
  const first = store.guest(token);
  assert.equal(first.tier, "guest");
  assert.deepEqual(first.providers, ["soundcloud"]);
  assert.equal(first.capabilities["rooms.join"], false);
  advance(.5);
  assert.equal(store.guest(token).expiresAt, first.expiresAt);
  store.bindGuest("alice", token);
  assert.equal(store.snapshot("alice").expiresAt, first.expiresAt);
  store.bindGuest("bob", token);
  assert.equal(store.snapshot("bob").tier, "none");
  assert.equal(store.snapshot(undefined, token).tier, "none");
  advance(.5);
  assert.equal(store.snapshot("alice").tier, "none");
  assert.equal(store.guest(token).tier, "none");
  assert.throws(() => store.require("playback.soundcloud", "alice"), fails("SUBSCRIPTION_REQUIRED"));
});

test("an account with a bound trial invalidates a fresh anonymous token on login", t => {
  const { store, advance } = fixture(t);
  const original = randomBytes(32).toString("base64url");
  const reinstall = randomBytes(32).toString("base64url");
  store.guest(original);
  store.bindGuest("alice", original);
  advance(.25);
  store.guest(reinstall);
  assert.equal(store.snapshot(undefined, reinstall).tier, "guest");
  store.bindGuest("alice", reinstall);
  assert.equal(store.snapshot("alice").tier, "guest");
  assert.equal(store.snapshot(undefined, reinstall).tier, "none");
});

test("guest Wave has persistent three-batch allowance and cannot use Yandex", t => {
  const { store } = fixture(t); const token = randomBytes(32).toString("base64url"); store.guest(token);
  for (let i = 0; i < 3; i++) store.consumeGuestWave(undefined, token);
  store.bindGuest("alice", token);
  assert.throws(() => store.consumeGuestWave("alice"), fails("GUEST_WAVE_LIMIT"));
  assert.throws(() => store.require("playback.yandex", "alice"), fails("SUBSCRIPTION_REQUIRED"));
});

test("one-use redemption is durable, hashes codes and is idempotent for same user", t => {
  const { store, issue, path } = fixture(t); const promo = issue("plus", 30);
  const first = store.redeem("alice", promo.code);
  assert.equal(first.tier, "plus");
  assert.deepEqual(store.redeem("alice", promo.code), first);
  assert.throws(() => store.redeem("bob", promo.code), fails("PROMO_UNAVAILABLE"));
  const other = new SubscriptionStore(path);
  assert.equal(other.snapshot("alice").tier, "plus"); other.close();
  assert.equal(readFileSync(path).includes(Buffer.from(promo.code)), false);
});

test("invalid, expired and revoked codes grant nothing", t => {
  const { store, issue, advance } = fixture(t);
  const revoked = issue("base", 30); store.revokePromo(revoked.id, "admin");
  assert.throws(() => store.redeem("alice", revoked.code), fails("PROMO_UNAVAILABLE"));
  const expired = issue("plus", 30, 1); advance(1);
  assert.throws(() => store.redeem("alice", expired.code), fails("PROMO_UNAVAILABLE"));
  assert.equal(store.snapshot("alice").tier, "none");
});

test("extension, upgrade and downgrade preserve all purchased time", t => {
  const { store, issue, advance } = fixture(t);
  store.redeem("alice", issue("base", 30).code);
  advance(10);
  let value = store.redeem("alice", issue("plus", 5).code);
  assert.equal(value.tier, "plus"); assert.equal(value.scheduled[0]?.plan, "base");
  store.redeem("alice", issue("base", 2).code);
  advance(5); assert.equal(store.snapshot("alice").tier, "base");
  advance(20); assert.equal(store.snapshot("alice").tier, "base");
  advance(2); assert.equal(store.snapshot("alice").tier, "none");
});

test("family invitations are single-use, enforce five people and expire with owner", t => {
  const { store, issue, advance } = fixture(t);
  store.redeem("owner", issue("family", 30).code);
  const old = store.invite("owner"); const current = store.invite("owner");
  assert.throws(() => store.joinFamily("old", old), fails("INVITE_INVALID"));
  store.joinFamily("m1", current);
  assert.throws(() => store.joinFamily("replay", current), fails("INVITE_INVALID"));
  for (let i = 2; i <= 4; i++) store.joinFamily(`m${i}`, store.invite("owner"));
  assert.throws(() => store.joinFamily("m5", store.invite("owner")), fails("FAMILY_FULL"));
  assert.equal(store.snapshot("m1").tier, "family");
  assert.equal(store.snapshot("m1").capabilities["family.manage"], false);
  store.leaveFamily("intruder", "m1"); assert.equal(store.snapshot("m1").tier, "family");
  store.leaveFamily("owner", "m1"); assert.equal(store.snapshot("m1").tier, "none");
  advance(30); assert.equal(store.snapshot("m2").tier, "none");
});

test("base devices capped at two; device removals cannot affect other accounts", t => {
  const { store, issue } = fixture(t); store.redeem("alice", issue("base", 30).code);
  const ids = ["a", "b", "c"].map(x => x.repeat(32));
  store.touchDevice("alice", ids[0]!); store.touchDevice("alice", ids[1]!);
  assert.throws(() => store.touchDevice("alice", ids[2]!), fails("DEVICE_LIMIT"));
  store.removeDevice("bob", ids[0]!); assert.equal(store.devices("alice").length, 2);
  store.removeDevice("alice", ids[0]!); store.touchDevice("alice", ids[2]!);
});

test("bot only issues to allowlisted admin in private chat and retries generate same code", t => {
  const { store } = fixture(t); const admins = new Set(["123"]);
  const update = { update_id: 42, message: { from: { id: 123 }, chat: { id: 123, type: "private" }, text: "/promo plus 30" } };
  const result = processPromoCommand(store, update, admins, "test secret")!;
  assert.equal(processPromoCommand(store, update, admins, "test secret"), result);
  assert.match(result, /Код: RSN-/);
  assert.equal(processPromoCommand(store, update, new Set(), "test secret"), undefined);
  assert.equal(processPromoCommand(store, { ...update, message: { ...update.message, chat: { id: -100, type: "group" } } }, admins, "test secret"), undefined);
  const code = result.match(/Код: (RSN-[A-Z0-9-]+)/)![1]!;
  assert.equal(store.redeem("alice", code).tier, "plus");
  assert.throws(() => store.redeem("bob", code), fails("PROMO_UNAVAILABLE"));
});

test("bot fails closed without proxy or administrator; accepts only supported proxy protocol", async t => {
  const env = { PROMO_BOT_TOKEN: '123:' + 'a'.repeat(32), PROMO_CODE_SECRET: 's'.repeat(32), PROMO_BOT_ADMIN_IDS: '123', PROMO_BOT_PROXY_URL: 'http://login:secret@127.0.0.1:8080' };
  assert.equal(botConfiguration(env).admins.has('123'), true);
  assert.equal(botConfiguration(env).codeSecret, env.PROMO_CODE_SECRET);
  assert.throws(() => botConfiguration({ ...env, PROMO_BOT_PROXY_URL: '' }));
  assert.throws(() => botConfiguration({ ...env, PROMO_BOT_ADMIN_IDS: '' }));
  assert.throws(() => botConfiguration({ ...env, PROMO_CODE_SECRET: '' }));
  assert.throws(() => botConfiguration({ ...env, PROMO_CODE_SECRET: 'too-short' }));
  assert.throws(() => botConfiguration({ ...env, PROMO_BOT_PROXY_URL: 'file:///tmp/proxy' }));
  const { store } = fixture(t);
  const controller = new AbortController(); controller.abort();
  let dispatcher: unknown;
  await runPromoBot(store, env, controller.signal, async (_url, init) => {
    dispatcher = init?.dispatcher;
    return new Response(JSON.stringify({ ok: true, result: {} }), { status: 200, headers: { 'content-type': 'application/json' } });
  });
  assert.ok(dispatcher, 'Telegram must receive a ProxyAgent dispatcher even before polling');
});
