import assert from "node:assert/strict";
import { test } from "node:test";
import express from "express";
import { jsonErrorHandler } from "./error-handler.js";

const serve = async () => {
  const app = express();
  app.use(express.json({ limit: "1kb" }));
  app.post("/echo", (request, response) => { response.json(request.body); });
  app.get("/boom", () => { throw new Error("secret path C:\\srv\\index.ts"); });
  app.use(jsonErrorHandler);
  const server = app.listen(0, "127.0.0.1");
  await new Promise((resolve) => server.once("listening", resolve));
  const { port } = server.address() as { port: number };
  return { url: `http://127.0.0.1:${port}`, close: () => server.close() };
};

test("malformed, oversized and failing requests get JSON errors without stacks", async () => {
  const { url, close } = await serve();
  const original = console.error;
  console.error = () => undefined;
  try {
    const bad = await fetch(`${url}/echo`, { method: "POST", headers: { "content-type": "application/json" }, body: "{" });
    assert.equal(bad.status, 400);
    assert.deepEqual((await bad.json()).error.code, "INVALID_REQUEST");

    const big = await fetch(`${url}/echo`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ x: "a".repeat(4_000) })
    });
    assert.equal(big.status, 413);
    assert.equal((await big.json()).error.code, "PAYLOAD_TOO_LARGE");

    const boom = await fetch(`${url}/boom`);
    assert.equal(boom.status, 500);
    const text = await boom.text();
    assert.match(boom.headers.get("content-type") ?? "", /json/);
    assert.doesNotMatch(text, /secret|index\.ts|at /);
  } finally {
    console.error = original;
    close();
  }
});
