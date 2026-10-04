import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";
import test from "node:test";
import { getGlobalDispatcher, setGlobalDispatcher } from "undici";
import { hostMatches, installProviderProxy } from "./outbound-proxy.js";

test("matches provider hosts by suffix only", () => {
  assert.equal(hostMatches("api.spotify.com", ["spotify.com"]), true);
  assert.equal(hostMatches("www.youtube.com.", ["youtube.com"]), true);
  assert.equal(hostMatches("notspotify.com", ["spotify.com"]), false);
});

test("global fetch sends provider hosts through the proxy and others directly", async () => {
  const seen: string[] = [];
  const proxy = createServer((request, response) => {
    seen.push(new URL(request.url ?? "").host);
    response.end("via-proxy");
  });
  // undici tunnels through the proxy with CONNECT, even for plain http targets.
  proxy.on("connect", (request, socket) => {
    seen.push((request.url ?? "").replace(/:80$/, ""));
    socket.write("HTTP/1.1 200 Connection Established\r\n\r\n");
    socket.once("data", () => socket.end("HTTP/1.1 200 OK\r\ncontent-length: 9\r\nconnection: close\r\n\r\nvia-proxy"));
  });
  proxy.listen(0, "127.0.0.1");
  const direct = createServer((_request, response) => response.end("direct")).listen(0, "127.0.0.1");
  await Promise.all([once(proxy, "listening"), once(direct, "listening")]);
  const previous = getGlobalDispatcher();
  try {
    const proxyPort = (proxy.address() as { port: number }).port;
    const hosts = installProviderProxy({ PROVIDER_PROXY_URL: `http://127.0.0.1:${proxyPort}` });
    assert.ok(hosts?.includes("spotify.com"));
    for (const url of ["http://api.spotify.com/v1/me", "http://api-v2.soundcloud.com/search", "http://www.youtube.com/youtubei/v1/search"]) {
      assert.equal(await (await fetch(url)).text(), "via-proxy", url);
    }
    assert.deepEqual(seen, ["api.spotify.com", "api-v2.soundcloud.com", "www.youtube.com"]);
    const directPort = (direct.address() as { port: number }).port;
    assert.equal(await (await fetch(`http://127.0.0.1:${directPort}/`)).text(), "direct");
    assert.equal(installProviderProxy({}), undefined);
  } finally {
    const installed = getGlobalDispatcher();
    setGlobalDispatcher(previous);
    await installed.destroy();
    proxy.closeAllConnections();
    direct.closeAllConnections();
    proxy.close();
    direct.close();
  }
});
