import express from "express";
import { z } from "zod";
import { AccountError, AccountStore } from "./account-store.js";
import { SubscriptionError, SubscriptionStore, hashSecret, type Capability } from "./subscriptions.js";

export type AccessIdentity = { userId?: string; guestToken?: string };
export class AccessControl {
  constructor(readonly accounts: AccountStore, readonly subscriptions: SubscriptionStore) {}
  identity(headers: { authorization?: string; guest?: string }): AccessIdentity {
    if (headers.authorization) {
      const token = headers.authorization.match(/^Bearer ([A-Za-z0-9_-]{30,256})$/)?.[1];
      if (!token) throw new SubscriptionError("AUTH_REQUIRED", "Войдите в аккаунт", 401);
      return { userId: this.accounts.authenticate(token).id };
    }
    return { guestToken: headers.guest };
  }
  fromRequest(request: express.Request) {
    return this.identity({ authorization: request.header("authorization"), guest: request.header("x-guest-token") });
  }
  require(request: express.Request, right: Capability) {
    const identity = this.fromRequest(request);
    this.subscriptions.require(right, identity.userId, identity.guestToken);
    if (identity.userId) this.subscriptions.touchDevice(identity.userId, request.header("x-device-id") ?? "");
    return identity;
  }
  middleware(right: Capability): express.RequestHandler {
    return (request, response, next) => { try { this.require(request, right); next(); } catch (error) { accessError(response, error); } };
  }
}

/** Bounded fail-closed limiter; no evictions that grant a fresh budget on overflow. */
export class AccessLimiter {
  private readonly buckets = new Map<string, { count: number; until: number }>();
  constructor(private readonly limit: number, private readonly windowMs: number) {}
  allow(key: string) {
    const now = Date.now();
    for (const [k, b] of this.buckets) if (b.until <= now) this.buckets.delete(k);
    const bucket = this.buckets.get(key);
    if (!bucket) {
      if (this.buckets.size >= 10_000) return false;
      this.buckets.set(key, { count: 1, until: now + this.windowMs }); return true;
    }
    return ++bucket.count <= this.limit;
  }
}

export function createSubscriptionRouter(access: AccessControl) {
  const router = express.Router();
  const store = access.subscriptions;
  const guests = new AccessLimiter(5, 86_400_000);
  const redemptions = new AccessLimiter(10, 900_000);
  const ipRedemptions = new AccessLimiter(30, 900_000);
  const actions = new AccessLimiter(30, 60_000);
  router.use((_q, r, next) => { r.setHeader("cache-control", "private, no-store"); next(); });
  const route = (action: (q: express.Request, r: express.Response) => void): express.RequestHandler => (q, r) => {
    try { action(q, r); } catch (error) { accessError(r, error); }
  };
  const user = (q: express.Request) => {
    const id = access.fromRequest(q).userId;
    if (!id) throw new SubscriptionError("AUTH_REQUIRED", "Для активации войдите в аккаунт", 401);
    return id;
  };
  const limited = () => { throw new SubscriptionError("RATE_LIMITED", "Слишком много попыток. Попробуйте позже", 429); };
  router.post("/guest", route((q, r) => {
    const input = z.object({ token: z.string().regex(/^[A-Za-z0-9_-]{40,128}$/) }).strict().parse(q.body);
    if (!guests.allow(hashSecret(q.ip ?? "unknown"))) limited();
    r.json({ subscription: store.guest(input.token) });
  }));
  router.get("/status", route((q, r) => {
    const identity = access.fromRequest(q);
    if (identity.userId) store.bindGuest(identity.userId, q.header("x-guest-token"));
    r.json({ subscription: store.snapshot(identity.userId, identity.guestToken), serverTime: new Date().toISOString() });
  }));
  router.post("/redeem", route((q, r) => {
    const id = user(q);
    if (!redemptions.allow(id) || !ipRedemptions.allow(hashSecret(q.ip ?? "unknown"))) limited();
    const input = z.object({ code: z.string().trim().min(20).max(100) }).strict().parse(q.body);
    r.json({ subscription: store.redeem(id, input.code) });
  }));
  router.get("/devices", route((q, r) => { r.json({ devices: store.devices(user(q)) }); }));
  router.delete("/devices/:id", route((q, r) => {
    const id = user(q);
    if (!actions.allow(id)) limited();
    store.removeDevice(id, String(q.params.id)); r.status(204).end();
  }));
  router.get("/family", route((q, r) => { r.json({ members: store.family(user(q)) }); }));
  router.post("/family/invite", route((q, r) => {
    const id = user(q); if (!actions.allow(id)) limited();
    r.json({ invitation: store.invite(id) });
  }));
  router.post("/family/join", route((q, r) => {
    const id = user(q); if (!actions.allow(id)) limited();
    const input = z.object({ invitation: z.string().regex(/^[A-Za-z0-9_-]{32}$/) }).strict().parse(q.body);
    store.joinFamily(id, input.invitation); r.json({ subscription: store.snapshot(id) });
  }));
  router.delete("/family/:memberId", route((q, r) => { store.leaveFamily(user(q), String(q.params.memberId)); r.status(204).end(); }));
  return router;
}

export function accessError(response: express.Response, error: unknown) {
  if (error instanceof SubscriptionError || error instanceof AccountError) {
    if (error.status === 429) response.setHeader("retry-after", "900");
    response.status(error.status).json({ error: { code: error.code, message: error.message } }); return;
  }
  if (error instanceof z.ZodError) { response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Проверьте введённые данные" } }); return; }
  response.status(500).json({ error: { code: "ACCESS_ERROR", message: "Не удалось проверить доступ" } });
}
