import assert from "node:assert/strict";
import { test } from "node:test";
import { CallBudget, optionalUser, TtlCache } from "./api-helpers.js";

test("TtlCache drops expired entries before evicting live ones", async () => {
  let now = 0;
  const cache = new TtlCache<number>(10, 2, () => now);
  await cache.get("old", async () => 1);
  now = 5;
  await cache.get("live", async () => 2);
  now = 12; // "old" expired, "live" still fresh
  await cache.get("new", async () => 3);
  assert.equal(cache.peek("live"), 2, "live entry survived");
  assert.equal(cache.peek("old"), undefined);
  assert.equal(cache.size, 2);
});

test("CallBudget and optionalUser", () => {
  const budget = new CallBudget(3);
  assert.equal(budget.take(2), true);
  assert.equal(budget.take(2), false);
  assert.equal(budget.take(), true);
  assert.equal(optionalUser(() => { throw new Error("expired"); }, {} as never), undefined);
  assert.equal(optionalUser(() => "u1", {} as never), "u1");
});
