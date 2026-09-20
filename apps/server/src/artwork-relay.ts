import { ProviderGatewayError } from "./provider-gateway.js";
import type { ProxiedFetch } from "./upstream-proxy.js";

const relayPathPrefix = "/api/v1/media/artwork/";
const ticketPattern = /^[A-Za-z0-9_-]{12,5600}$/;
const allowedArtworkHosts = [
  "sndcdn.com",
  "scdn.co",
  "spotifycdn.com",
  "ytimg.com",
  "yt3.ggpht.com",
  "yt3.googleusercontent.com"
];

export class ArtworkRelay {
  constructor(private readonly request: ProxiedFetch) {}

  canRelay(value: string) {
    try {
      assertAllowedArtworkUrl(value);
      return true;
    } catch {
      return false;
    }
  }

  issue(value: string) {
    assertAllowedArtworkUrl(value);
    const ticket = Buffer.from(value, "utf8").toString("base64url");
    if (!ticketPattern.test(ticket)) {
      throw new ProviderGatewayError(
        "UPSTREAM_ERROR",
        "Artwork URL is too long to relay",
        502
      );
    }
    return `${relayPathPrefix}${ticket}`;
  }

  async open(ticket: string, method: "GET" | "HEAD", incomingHeaders: Record<string, string | undefined>) {
    const initialUrl = decodeTicket(ticket);
    let url = new URL(initialUrl);
    for (let redirect = 0; redirect <= 3; redirect += 1) {
      assertAllowedArtworkUrl(url.toString());
      const headers = new Headers({ accept: "image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8" });
      for (const name of ["if-none-match", "if-modified-since"]) {
        const value = incomingHeaders[name];
        if (value) headers.set(name, value);
      }
      let response: Response;
      try {
        response = await this.request(url, {
          method,
          headers,
          redirect: "manual",
          signal: AbortSignal.timeout(12_000)
        });
      } catch (error) {
        throw new ProviderGatewayError(
          "PROXY_CONNECTION_FAILED",
          "Artwork relay could not reach the provider",
          502,
          { cause: error }
        );
      }
      if ([301, 302, 303, 307, 308].includes(response.status)) {
        const location = response.headers.get("location");
        if (!location || redirect === 3) {
          throw new ProviderGatewayError("UPSTREAM_ERROR", "Artwork relay received an invalid redirect", 502);
        }
        url = new URL(location, url);
        continue;
      }
      const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
      if (![200, 304].includes(response.status) || (response.status === 200 && !contentType.startsWith("image/"))) {
        throw new ProviderGatewayError("UPSTREAM_ERROR", "Artwork provider returned an invalid response", 502);
      }
      const declaredLength = Number(response.headers.get("content-length"));
      if (Number.isFinite(declaredLength) && declaredLength > 12 * 1024 * 1024) {
        throw new ProviderGatewayError("UPSTREAM_ERROR", "Artwork is too large", 502);
      }
      return response;
    }
    throw new ProviderGatewayError("UPSTREAM_ERROR", "Artwork relay exceeded its redirect limit", 502);
  }
}

export function rewriteArtworkUrls(value: unknown, relay: ArtworkRelay, absoluteUrl: (path: string) => string): unknown {
  if (Array.isArray(value)) return value.map((item) => rewriteArtworkUrls(item, relay, absoluteUrl));
  if (!value || typeof value !== "object") return value;
  const source = value as Record<string, unknown>;
  return Object.fromEntries(Object.entries(source).map(([key, item]) => {
    if (key === "artworkUrl" && typeof item === "string" && relay.canRelay(item)) {
      return [key, absoluteUrl(relay.issue(item))];
    }
    return [key, rewriteArtworkUrls(item, relay, absoluteUrl)];
  }));
}

export function isArtworkRelayTicket(value: string) {
  return ticketPattern.test(value);
}

function decodeTicket(ticket: string) {
  if (!ticketPattern.test(ticket)) throw relayNotFound();
  let value: string;
  try {
    value = Buffer.from(ticket, "base64url").toString("utf8");
  } catch {
    throw relayNotFound();
  }
  if (Buffer.from(value, "utf8").toString("base64url") !== ticket) throw relayNotFound();
  assertAllowedArtworkUrl(value);
  return value;
}

function assertAllowedArtworkUrl(value: string) {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw relayNotFound();
  }
  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    !allowedArtworkHosts.some((host) => url.hostname === host || url.hostname.endsWith(`.${host}`))
  ) {
    throw relayNotFound();
  }
}

function relayNotFound() {
  return new ProviderGatewayError("TRACK_NOT_FOUND", "Artwork relay URL is invalid", 404);
}
