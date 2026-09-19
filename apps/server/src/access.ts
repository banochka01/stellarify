import { createHash } from "node:crypto";
import express from "express";
import { z } from "zod";
import { AccountError, AccountStore } from "./account-store.js";

export const hashSecret = (value: string) =>
  createHash("sha256").update(value).digest("hex");

export class AccessError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status = 403
  ) {
    super(message);
  }
}

export type AccessIdentity = { userId?: string; guestToken?: string };

export class AccessControl {
  constructor(readonly accounts: AccountStore) {}

  identity(headers: { authorization?: string; guest?: string }): AccessIdentity {
    if (headers.authorization) {
      const token = headers.authorization.match(
        /^Bearer ([A-Za-z0-9_-]{30,256})$/
      )?.[1];
      if (!token) throw new AccessError("AUTH_REQUIRED", "Войдите в аккаунт", 401);
      return { userId: this.accounts.authenticate(token).id };
    }
    return { guestToken: headers.guest };
  }

  fromRequest(request: express.Request) {
    return this.identity({
      authorization: request.header("authorization"),
      guest: request.header("x-guest-token")
    });
  }
}

const freeCapabilities = {
  "playback.soundcloud": true,
  "playback.spotify": true,
  "playback.yandex": true,
  "playback.vk": true,
  "library.cloudSync": true,
  "library.import": true,
  "wave.standard": true,
  "wave.personalized": true,
  "rooms.join": true,
  "rooms.create": true,
  "family.manage": false
};

// Old native releases still call these endpoints before provider requests.
// Keep the response shape stable while granting every Resonance capability.
export function freeAccessSnapshot() {
  return {
    tier: "free",
    accessModel: "free",
    expiresAt: "2099-12-31T23:59:59.999Z",
    capabilities: { ...freeCapabilities },
    providers: ["soundcloud", "yandex", "spotify", "vk"],
    deviceLimit: 2_147_483_647,
    familyOwnerId: null,
    scheduled: []
  };
}

export function createLegacyAccessRouter(access: AccessControl) {
  const router = express.Router();
  router.use((_request, response, next) => {
    response.setHeader("cache-control", "private, no-store");
    next();
  });
  const route = (
    action: (request: express.Request, response: express.Response) => void
  ): express.RequestHandler => (request, response) => {
    try {
      action(request, response);
    } catch (error) {
      accessError(response, error);
    }
  };
  const account = (request: express.Request) => {
    const id = access.fromRequest(request).userId;
    if (!id) throw new AccessError("AUTH_REQUIRED", "Войдите в аккаунт", 401);
    return id;
  };

  router.post("/guest", route((request, response) => {
    z.object({ token: z.string().regex(/^[A-Za-z0-9_-]{40,128}$/) })
      .strict()
      .parse(request.body);
    response.json({ subscription: freeAccessSnapshot() });
  }));
  router.get("/status", route((request, response) => {
    access.fromRequest(request);
    response.json({
      subscription: freeAccessSnapshot(),
      serverTime: new Date().toISOString()
    });
  }));
  router.post("/redeem", route((request, response) => {
    account(request);
    response.json({ subscription: freeAccessSnapshot() });
  }));
  router.get("/devices", route((request, response) => {
    account(request);
    response.json({ devices: [] });
  }));
  router.get("/family", route((request, response) => {
    account(request);
    response.json({ members: [] });
  }));
  return router;
}

export function accessError(response: express.Response, error: unknown) {
  if (error instanceof AccessError || error instanceof AccountError) {
    response.status(error.status).json({
      error: { code: error.code, message: error.message }
    });
    return;
  }
  if (error instanceof z.ZodError) {
    response.status(400).json({
      error: { code: "INVALID_REQUEST", message: "Проверьте введённые данные" }
    });
    return;
  }
  response.status(500).json({
    error: { code: "ACCESS_ERROR", message: "Не удалось проверить доступ" }
  });
}
