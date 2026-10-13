import { createServer, type Server } from "node:http";
import express from "express";
import type { Authenticate } from "./api-helpers.js";

/** Test-only: authenticates by the `x-test-user` header. */
export const headerAuth: Authenticate = (request) => request.header("x-test-user") || undefined;

/** Test-only: like headerAuth, but user `bad` simulates an expired Bearer token (throws 401). */
export const strictHeaderAuth: Authenticate = (request) => {
  const user = request.header("x-test-user");
  if (user === "bad") throw Object.assign(new Error("Сессия истекла"), { code: "INVALID_SESSION", status: 401 });
  return user || undefined;
};

/** Test-only: mounts a router on an ephemeral port and returns a small JSON client. */
export async function serveRouter(path: string, router: express.Router) {
  const app = express();
  app.use(express.json({ limit: "64kb" }));
  app.use(path, router);
  const server: Server = createServer(app);
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  if (!address || typeof address !== "object") throw new Error("no address");
  const base = `http://127.0.0.1:${address.port}${path}`;
  const call = async (method: string, route: string, user?: string, body?: unknown) => {
    const response = await fetch(`${base}${route}`, {
      method,
      headers: { "content-type": "application/json", ...(user ? { "x-test-user": user } : {}) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) })
    });
    const text = await response.text();
    return { status: response.status, headers: response.headers, body: text ? JSON.parse(text) as any : undefined };
  };
  return {
    call,
    close: () => new Promise<void>((resolve) => server.close(() => resolve()))
  };
}
