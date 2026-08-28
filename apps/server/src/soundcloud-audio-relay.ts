import { randomBytes } from "node:crypto";
import { ProxyAgent, type Dispatcher } from "undici";
import { ProviderGatewayError, type ResolvedStream } from "./provider-gateway.js";
import { assertAllowedStreamUrl, normalizeProxyUrl } from "./soundcloud.js";

type RequestInitWithDispatcher = RequestInit & { dispatcher?: Dispatcher };
type RequestFunction = (
  input: string | URL,
  init?: RequestInitWithDispatcher
) => Promise<Response>;

type RelayEntry = { streamUrl: string; expiresAt: number };
export type SoundCloudRelayTicket = {
  streamUrl: string;
  expiresAt: string;
};

const relayPathPrefix = "/api/v1/playback/soundcloud-relay/";
const ticketPattern = /^[A-Za-z0-9_-]{32}$/;

export class SoundCloudAudioRelay {
  readonly available: boolean;
  private readonly proxyAgent?: ProxyAgent;
  private readonly entries = new Map<string, RelayEntry>();

  constructor(
    proxyUrl?: string,
    private readonly request: RequestFunction = fetch,
    private readonly now: () => number = Date.now,
    private readonly createTicket: () => string = () =>
      randomBytes(24).toString("base64url"),
    private readonly maxEntries = 1_000
  ) {
    const normalized = normalizeProxyUrl(proxyUrl);
    this.proxyAgent = normalized ? new ProxyAgent(normalized) : undefined;
    this.available = this.proxyAgent !== undefined;
  }

  issue(stream: ResolvedStream): SoundCloudRelayTicket {
    if (!this.proxyAgent) {
      throw new ProviderGatewayError(
        "PROXY_NOT_CONFIGURED",
        "The SoundCloud audio relay is not configured",
        503
      );
    }
    if (stream.protocol !== "progressive") {
      throw new ProviderGatewayError(
        "STREAM_UNAVAILABLE",
        "SoundCloud audio relay currently requires a progressive stream",
        409
      );
    }
    assertAllowedStreamUrl(stream.streamUrl);
    this.prune();
    while (this.entries.size >= this.maxEntries) {
      const oldest = this.entries.keys().next().value;
      if (!oldest) break;
      this.entries.delete(oldest);
    }

    const ticket = this.createTicket();
    if (!ticketPattern.test(ticket)) {
      throw new Error("SoundCloud relay generated an invalid ticket");
    }
    const declaredExpiry = stream.expiresAt
      ? Date.parse(stream.expiresAt)
      : Number.NaN;
    const expiresAt = Number.isFinite(declaredExpiry)
      ? Math.min(declaredExpiry - 15_000, this.now() + 30 * 60_000)
      : this.now() + 30 * 60_000;
    if (expiresAt <= this.now()) {
      throw new ProviderGatewayError(
        "STREAM_UNAVAILABLE",
        "The SoundCloud stream expired before relay playback started",
        409
      );
    }
    this.entries.set(ticket, { streamUrl: stream.streamUrl, expiresAt });
    return {
      streamUrl: `${relayPathPrefix}${ticket}`,
      expiresAt: new Date(expiresAt).toISOString()
    };
  }

  async open(
    ticket: string,
    method: "GET" | "HEAD",
    incomingHeaders: Record<string, string | undefined>
  ): Promise<Response> {
    if (!ticketPattern.test(ticket)) throw relayNotFound();
    const entry = this.entries.get(ticket);
    if (!entry || entry.expiresAt <= this.now()) {
      this.entries.delete(ticket);
      throw relayNotFound();
    }

    const headers = new Headers();
    for (const name of [
      "range",
      "if-range",
      "if-none-match",
      "if-modified-since"
    ]) {
      const value = incomingHeaders[name];
      if (value) headers.set(name, value);
    }
    return this.requestFollowingSafeRedirects(entry.streamUrl, method, headers);
  }

  private async requestFollowingSafeRedirects(
    initialUrl: string,
    method: "GET" | "HEAD",
    headers: Headers
  ) {
    let url = new URL(initialUrl);
    for (let redirect = 0; redirect <= 3; redirect += 1) {
      assertAllowedStreamUrl(url.toString());
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 15_000);
      let response: Response;
      try {
        response = await this.request(url, {
          method,
          headers,
          redirect: "manual",
          signal: controller.signal,
          dispatcher: this.proxyAgent
        });
      } catch (error) {
        throw new ProviderGatewayError(
          "PROXY_CONNECTION_FAILED",
          "The SoundCloud audio relay could not reach the provider",
          502,
          { cause: error }
        );
      } finally {
        clearTimeout(timeout);
      }

      if (![301, 302, 303, 307, 308].includes(response.status)) return response;
      const location = response.headers.get("location");
      if (!location || redirect === 3) {
        throw new ProviderGatewayError(
          "UPSTREAM_ERROR",
          "SoundCloud audio relay received an invalid redirect",
          502
        );
      }
      url = new URL(location, url);
    }
    throw new ProviderGatewayError(
      "UPSTREAM_ERROR",
      "SoundCloud audio relay exceeded its redirect limit",
      502
    );
  }

  private prune() {
    const now = this.now();
    for (const [ticket, entry] of this.entries) {
      if (entry.expiresAt <= now) this.entries.delete(ticket);
    }
  }
}

export function isSoundCloudRelayTicket(value: string) {
  return ticketPattern.test(value);
}

function relayNotFound() {
  return new ProviderGatewayError(
    "TRACK_NOT_FOUND",
    "SoundCloud relay ticket was not found or expired",
    404
  );
}
