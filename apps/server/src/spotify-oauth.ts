import { createHash, randomBytes } from "node:crypto";
import { Router } from "express";
import { z } from "zod";
import { encodeSpotifyCredential } from "./spotify-oauth-credential.js";

type PendingLogin = {
  requestId: string;
  verifier: string;
  expiresAt: number;
  status: "pending" | "complete" | "error";
  credential?: string;
  error?: string;
};

const callbackSchema = z.object({
  state: z.string().min(20).max(200),
  code: z.string().min(1).max(2048).optional(),
  error: z.string().max(200).optional()
});

export class SpotifyOAuthService {
  private readonly byState = new Map<string, PendingLogin>();
  private readonly byRequest = new Map<string, PendingLogin>();

  constructor(
    private readonly clientId: string,
    readonly redirectUri: string,
    private readonly request: typeof fetch = fetch,
    private readonly now: () => number = Date.now
  ) {}

  get configured() {
    return Boolean(this.clientId.trim() && this.redirectUri.trim());
  }

  start() {
    if (!this.configured) throw new Error("Spotify OAuth is not configured");
    this.cleanup();
    const requestId = randomBytes(24).toString("base64url");
    const state = randomBytes(24).toString("base64url");
    const verifier = randomBytes(48).toString("base64url");
    const challenge = createHash("sha256").update(verifier).digest("base64url");
    const login: PendingLogin = { requestId, verifier, expiresAt: this.now() + 5 * 60_000, status: "pending" };
    this.byState.set(state, login);
    this.byRequest.set(requestId, login);
    const authorizeUrl = new URL("https://accounts.spotify.com/authorize");
    authorizeUrl.search = new URLSearchParams({
      client_id: this.clientId,
      response_type: "code",
      redirect_uri: this.redirectUri,
      state,
      scope: "user-library-read playlist-read-private playlist-read-collaborative",
      code_challenge_method: "S256",
      code_challenge: challenge,
      show_dialog: "true"
    }).toString();
    return { requestId, authorizeUrl: authorizeUrl.toString(), expiresIn: 300 };
  }

  async callback(input: unknown) {
    const parsed = callbackSchema.safeParse(input);
    if (!parsed.success) return { ok: false, message: "Некорректный ответ Spotify." };
    const login = this.byState.get(parsed.data.state);
    this.byState.delete(parsed.data.state);
    if (!login || login.expiresAt <= this.now()) {
      return { ok: false, message: "Ссылка входа устарела. Вернитесь в Resonance и попробуйте ещё раз." };
    }
    if (parsed.data.error || !parsed.data.code) {
      login.status = "error";
      login.error = parsed.data.error === "access_denied" ? "Вход отменён." : "Spotify не разрешил подключение.";
      return { ok: false, message: login.error };
    }
    try {
      const response = await this.request("https://accounts.spotify.com/api/token", {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: this.clientId,
          grant_type: "authorization_code",
          code: parsed.data.code,
          redirect_uri: this.redirectUri,
          code_verifier: login.verifier
        }),
        signal: AbortSignal.timeout(10_000)
      });
      const payload = z.object({ refresh_token: z.string().min(1) }).safeParse(await response.json().catch(() => ({})));
      if (!response.ok || !payload.success) throw new Error("Spotify token exchange failed");
      login.credential = encodeSpotifyCredential(payload.data.refresh_token);
      login.status = "complete";
      return { ok: true, message: "Spotify подключён. Можно вернуться в Resonance." };
    } catch {
      login.status = "error";
      login.error = "Не удалось завершить вход Spotify. Попробуйте ещё раз.";
      return { ok: false, message: login.error };
    }
  }

  status(requestId: string) {
    this.cleanup();
    const login = this.byRequest.get(requestId);
    if (!login) return { status: 404, body: { error: { code: "SPOTIFY_LOGIN_NOT_FOUND", message: "Вход не найден или устарел" } } };
    if (login.status === "pending") return { status: 202, body: { status: "pending" } };
    this.byRequest.delete(requestId);
    if (login.status === "error") return { status: 400, body: { error: { code: "SPOTIFY_LOGIN_FAILED", message: login.error } } };
    return { status: 200, body: { status: "complete", credential: login.credential } };
  }

  private cleanup() {
    for (const [requestId, login] of this.byRequest) {
      if (login.expiresAt <= this.now()) {
        this.byRequest.delete(requestId);
        for (const [state, candidate] of this.byState) if (candidate === login) this.byState.delete(state);
      }
    }
  }
}

export function createSpotifyOAuthRouter(service: SpotifyOAuthService) {
  const router = Router();
  router.post("/start", (_request, response) => {
    if (!service.configured) return void response.status(503).json({ error: { code: "SPOTIFY_OAUTH_NOT_CONFIGURED", message: "Вход Spotify пока не настроен" } });
    response.status(201).json(service.start());
  });
  router.get("/callback", async (request, response) => {
    const result = await service.callback(request.query);
    response.status(result.ok ? 200 : 400).type("html").send(`<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Resonance · Spotify</title><body style="margin:0;background:#0c0b0a;color:#eee9de;font:18px system-ui;display:grid;min-height:100vh;place-items:center"><main style="max-width:560px;padding:32px;text-align:center"><h1>${result.ok ? "Spotify подключён" : "Вход не завершён"}</h1><p>${escapeHtml(result.message)}</p><p style="color:#918c84">Эту вкладку можно закрыть.</p></main></body></html>`);
  });
  router.get("/status", (request, response) => {
    const requestId = typeof request.query.requestId === "string" ? request.query.requestId : "";
    const result = service.status(requestId);
    response.status(result.status).json(result.body);
  });
  return router;
}

function escapeHtml(value: string) {
  return value.replace(/[&<>"']/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]!);
}
