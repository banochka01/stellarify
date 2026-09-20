import assert from "node:assert/strict";
import test from "node:test";
import { decodeSpotifyCredential, encodeSpotifyCredential } from "./spotify-oauth-credential.js";
import { SpotifyOAuthService } from "./spotify-oauth.js";
import { SpotifyAdapter } from "./spotify.js";

test("Spotify OAuth uses PKCE and returns a refresh-capable device credential", async () => {
  let tokenBody = "";
  const service = new SpotifyOAuthService(
    "client-id",
    "https://music.example/api/v1/auth/spotify/callback",
    async (_input, init) => {
      tokenBody = String(init?.body);
      return Response.json({ access_token: "access", refresh_token: "refresh-secret", expires_in: 3600 });
    }
  );
  const started = service.start();
  const authorize = new URL(started.authorizeUrl);
  assert.equal(authorize.origin, "https://accounts.spotify.com");
  assert.equal(authorize.searchParams.get("code_challenge_method"), "S256");
  assert.match(authorize.searchParams.get("scope") ?? "", /user-library-read/);

  const callback = await service.callback({ state: authorize.searchParams.get("state"), code: "auth-code" });
  assert.equal(callback.ok, true);
  assert.match(tokenBody, /code_verifier=/);
  const status = service.status(started.requestId);
  assert.equal(status.status, 200);
  const credential = (status.body as { credential: string }).credential;
  assert.equal(decodeSpotifyCredential(credential), "refresh-secret");
  assert.equal(service.status(started.requestId).status, 404);
});

test("Spotify OAuth rejects unknown callback state", async () => {
  const service = new SpotifyOAuthService("client", "https://music.example/callback");
  assert.equal((await service.callback({ state: "x".repeat(24), code: "code" })).ok, false);
});

test("Spotify adapter refreshes an OAuth credential and reuses the short-lived access token", async () => {
  let refreshes = 0;
  let apiCalls = 0;
  const adapter = new SpotifyAdapter({ clientId: "client" }, async (input, init) => {
    const url = new URL(String(input));
    if (url.hostname === "accounts.spotify.com") {
      refreshes++;
      assert.match(String(init?.body), /refresh_token=refresh-secret/);
      return Response.json({ access_token: "fresh-access", expires_in: 3600 });
    }
    apiCalls++;
    assert.equal(new Headers(init?.headers).get("authorization"), "Bearer fresh-access");
    return Response.json({ tracks: { items: [] } });
  });
  const access = { token: encodeSpotifyCredential("refresh-secret") };
  await adapter.validateAccess(access);
  await adapter.validateAccess(access);
  assert.equal(refreshes, 1);
  assert.equal(apiCalls, 2);
});

test("Spotify OAuth token exchange uses the injected server request transport", async () => {
  const calls: string[] = [];
  const service = new SpotifyOAuthService(
    "client-id",
    "https://music.example/api/v1/auth/spotify/callback",
    async (input) => {
      calls.push(String(input));
      return Response.json({ refresh_token: "refresh-secret" });
    }
  );
  const started = service.start();
  const authorize = new URL(started.authorizeUrl);
  const result = await service.callback({
    state: authorize.searchParams.get("state"),
    code: "code"
  });
  assert.equal(result.ok, true);
  assert.deepEqual(calls, ["https://accounts.spotify.com/api/token"]);
});
