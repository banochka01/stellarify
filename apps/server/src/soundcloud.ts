import { isIP } from "node:net";
import { z } from "zod";
import { ProxyAgent, type Dispatcher } from "undici";
import {
  type AudioQuality,
  type MusicProviderAdapter,
  type ProviderAccess,
  type ProviderTrack,
  ProviderGatewayError,
  type ResolvedStream
} from "./provider-gateway.js";

const trackSchema = z.object({
  urn: z.string().min(1).optional(),
  id: z.union([z.string(), z.number()]),
  title: z.string(),
  duration: z.number().nonnegative().optional(),
  artwork_url: z.string().url().nullable().optional(),
  permalink_url: z.string().url(),
  track_authorization: z.string().min(1).optional(),
  user: z.object({ username: z.string() }),
  media: z
    .object({
      transcodings: z.array(
        z.object({
          url: z.string().url(),
          preset: z.string().optional(),
          quality: z.string().optional(),
          format: z.object({
            protocol: z.string().min(1),
            mime_type: z.string().min(1)
          })
        })
      )
    })
    .optional()
});

const publicSearchSchema = z.object({ collection: z.array(trackSchema) });
const publicStreamSchema = z.object({ url: z.string().url() });
const oauthSearchSchema = z.object({ collection: z.array(trackSchema) });
const oauthStreamsSchema = z.object({
  hls_aac_160_url: z.string().url().optional(),
  hls_aac_96_url: z.string().url().optional()
});

interface SoundCloudCredentials {
  clientId?: string;
  proxyUrl?: string;
}

type RequestInitWithDispatcher = RequestInit & { dispatcher?: Dispatcher };
type RequestFunction = (
  input: string | URL,
  init?: RequestInitWithDispatcher
) => Promise<Response>;

type SoundCloudCredential =
  | { kind: "client_id"; value: string }
  | { kind: "oauth"; value: string };

type SoundCloudTrack = z.infer<typeof trackSchema>;
type SoundCloudTranscoding =
  NonNullable<SoundCloudTrack["media"]>["transcodings"][number];

export class SoundCloudAdapter implements MusicProviderAdapter {
  readonly name = "soundcloud" as const;
  readonly authentication = "user_token_or_server_credentials" as const;
  readonly configured = true;
  readonly serverCredentialConfigured: boolean;
  readonly proxyAvailable: boolean;
  private readonly proxyAgent?: ProxyAgent;

  constructor(
    private readonly credentials: SoundCloudCredentials,
    private readonly request: RequestFunction = fetch
  ) {
    this.serverCredentialConfigured = Boolean(credentials.clientId?.trim());
    this.proxyAgent = createProxyAgent(credentials.proxyUrl);
    this.proxyAvailable = this.proxyAgent !== undefined;
  }

  async validateAccess(access?: ProviderAccess): Promise<void> {
    const credential = this.resolveCredential(access);
    if (credential.kind === "client_id") {
      const url = new URL("https://api-v2.soundcloud.com/search/tracks");
      url.searchParams.set("q", "Resonance");
      url.searchParams.set("limit", "1");
      await this.publicApiJson(url, credential.value, access);
      return;
    }
    await this.oauthApiJson(new URL("https://api.soundcloud.com/me"), credential.value, access);
  }

  async searchTracks(
    query: string,
    limit: number,
    access?: ProviderAccess
  ): Promise<ProviderTrack[]> {
    const credential = this.resolveCredential(withoutBrowserCookie(access));
    if (credential.kind === "client_id") {
      const url = new URL("https://api-v2.soundcloud.com/search/tracks");
      url.searchParams.set("q", query);
      url.searchParams.set("limit", String(limit));
      url.searchParams.set("linked_partitioning", "true");
      const payload = publicSearchSchema.parse(
        await this.publicApiJson(url, credential.value, access)
      );
      return payload.collection.map(mapTrack);
    }

    const url = new URL("https://api.soundcloud.com/tracks");
    url.searchParams.set("q", query);
    url.searchParams.set("access", "playable");
    url.searchParams.set("limit", String(limit));
    url.searchParams.set("linked_partitioning", "true");
    const payload = oauthSearchSchema.parse(
      await this.oauthApiJson(url, credential.value, access)
    );
    return payload.collection.map(mapTrack);
  }

  async resolve(
    externalId: string,
    quality: AudioQuality,
    access?: ProviderAccess
  ): Promise<ResolvedStream> {
    const credential = this.resolveCredential(withoutBrowserCookie(access));
    if (credential.kind === "client_id") {
      return this.resolvePublic(externalId, quality, credential.value, access);
    }
    return this.resolveOauth(externalId, quality, credential.value, access);
  }

  private async resolvePublic(
    externalId: string,
    quality: AudioQuality,
    clientId: string,
    access?: ProviderAccess
  ): Promise<ResolvedStream> {
    const trackId = normalizeTrackId(externalId);
    const trackUrl = new URL(
      `https://api-v2.soundcloud.com/tracks/${encodeURIComponent(trackId)}`
    );
    const track = trackSchema.parse(
      await this.publicApiJson(trackUrl, clientId, access)
    );
    const transcoding = selectTranscoding(
      track.media?.transcodings ?? [],
      access?.useProxy ? "high" : quality
    );
    if (!transcoding) {
      throw new ProviderGatewayError(
        "STREAM_UNAVAILABLE",
        "SoundCloud did not return a playable stream",
        404
      );
    }

    const streamEndpoint = new URL(transcoding.url);
    if (track.track_authorization) {
      streamEndpoint.searchParams.set(
        "track_authorization",
        track.track_authorization
      );
    }
    const resolved = publicStreamSchema.parse(
      await this.publicApiJson(streamEndpoint, clientId, access)
    );
    assertAllowedStreamUrl(resolved.url);

    return {
      streamUrl: resolved.url,
      protocol:
        transcoding.format.protocol === "progressive" ? "progressive" : "hls",
      codec: codecFromMimeType(transcoding.format.mime_type),
      ...(parseStreamExpiry(resolved.url)
        ? { expiresAt: parseStreamExpiry(resolved.url) }
        : {})
    };
  }

  private async resolveOauth(
    externalId: string,
    quality: AudioQuality,
    accessToken: string,
    access?: ProviderAccess
  ): Promise<ResolvedStream> {
    const encodedId = encodeURIComponent(normalizeTrackUrn(externalId));
    const url = new URL(
      `https://api.soundcloud.com/tracks/${encodedId}/streams`
    );
    const streams = oauthStreamsSchema.parse(
      await this.oauthApiJson(url, accessToken, access)
    );
    const preferHigh = quality === "high" || quality === "lossless";
    const streamUrl = preferHigh
      ? streams.hls_aac_160_url ?? streams.hls_aac_96_url
      : streams.hls_aac_96_url ?? streams.hls_aac_160_url;

    if (!streamUrl) {
      throw new ProviderGatewayError(
        "STREAM_UNAVAILABLE",
        "SoundCloud did not return a playable AAC stream",
        404
      );
    }
    assertAllowedStreamUrl(streamUrl);
    return {
      streamUrl,
      protocol: "hls",
      codec: "aac",
      bitrate: streamUrl === streams.hls_aac_160_url ? 160_000 : 96_000,
      ...(parseStreamExpiry(streamUrl)
        ? { expiresAt: parseStreamExpiry(streamUrl) }
        : {})
    };
  }

  private resolveCredential(access?: ProviderAccess): SoundCloudCredential {
    const userCredential = normalizeUserCredential(access?.token);
    if (userCredential) return userCredential;
    const serverClientId = normalizeClientId(this.credentials.clientId, false);
    if (serverClientId) return { kind: "client_id", value: serverClientId };
    throw new ProviderGatewayError(
      "PROVIDER_AUTH_REQUIRED",
      "A SoundCloud Client ID or OAuth access token is required",
      401
    );
  }

  private async publicApiJson(
    url: URL,
    clientId: string,
    access?: ProviderAccess
  ): Promise<unknown> {
    url.searchParams.set("client_id", clientId);
    return this.requestJson(url, { Accept: "application/json" }, access);
  }

  private async oauthApiJson(
    url: URL,
    accessToken: string,
    access?: ProviderAccess
  ): Promise<unknown> {
    return this.requestJson(
      url,
      { Accept: "application/json", Authorization: `OAuth ${accessToken}` },
      access
    );
  }

  private async requestJson(
    url: URL,
    headers: Record<string, string>,
    access?: ProviderAccess
  ): Promise<unknown> {
    if (access?.useProxy && !this.proxyAgent) {
      throw new ProviderGatewayError(
        "PROXY_NOT_CONFIGURED",
        "The SoundCloud server proxy is not configured",
        503
      );
    }

    let response: Response;
    try {
      response = await this.request(url, {
        headers,
        signal: AbortSignal.timeout(8_000),
        ...(access?.useProxy ? { dispatcher: this.proxyAgent } : {})
      });
    } catch (error) {
      const timedOut = error instanceof Error && error.name === "TimeoutError";
      throw new ProviderGatewayError(
        timedOut
          ? "UPSTREAM_TIMEOUT"
          : access?.useProxy
            ? "PROXY_CONNECTION_FAILED"
            : "UPSTREAM_ERROR",
        timedOut
          ? "SoundCloud request timed out"
          : access?.useProxy
            ? "The SoundCloud server proxy could not reach the provider"
            : "SoundCloud request failed",
        502,
        { cause: error }
      );
    }

    if (response.status === 401) {
      throw new ProviderGatewayError(
        "INVALID_PROVIDER_TOKEN",
        "The SoundCloud Client ID or OAuth token was rejected",
        401
      );
    }
    if (response.status === 403) {
      throw new ProviderGatewayError(
        "PROVIDER_ACCESS_DENIED",
        "SoundCloud denied API access for this credential",
        403
      );
    }
    if (response.status === 429) {
      throw new ProviderGatewayError(
        "PROVIDER_RATE_LIMITED",
        "SoundCloud rate limit exceeded",
        429
      );
    }
    if (response.status === 404) {
      throw new ProviderGatewayError(
        "TRACK_NOT_FOUND",
        "SoundCloud track or stream was not found",
        404
      );
    }
    if (!response.ok) {
      throw new ProviderGatewayError(
        "UPSTREAM_ERROR",
        `SoundCloud returned HTTP ${response.status}`,
        502
      );
    }
    return response.json();
  }
}

function mapTrack(track: z.infer<typeof trackSchema>): ProviderTrack {
  return {
    id: track.urn ?? `soundcloud:tracks:${track.id}`,
    title: track.title,
    artist: track.user.username,
    durationMs: track.duration,
    artworkUrl: highResolutionArtwork(track.artwork_url),
    externalUrl: track.permalink_url
  };
}

function highResolutionArtwork(value?: string | null) {
  if (!value) return undefined;
  return value.replace(/-(?:large|t\d+x\d+)\.(jpg|jpeg|png)(\?.*)?$/i, "-t500x500.$1$2");
}

export function normalizeProxyUrl(value?: string) {
  const raw = value?.trim();
  if (!raw) return undefined;
  if (raw.length > 2_048 || /[\r\n]/.test(raw)) {
    throw new Error("SOUNDCLOUD_PROXY_URL is invalid");
  }

  if (!raw.includes("://")) {
    const parts = raw.split(":");
    if (parts.length !== 4) {
      throw new Error(
        "SOUNDCLOUD_PROXY_URL must use ip:port:login:password"
      );
    }
    const [ip = "", portValue = "", login = "", password = ""] = parts;
    const port = Number(portValue);
    if (
      isIP(ip) !== 4 ||
      !Number.isInteger(port) ||
      port < 1 ||
      port > 65_535 ||
      !login ||
      !password ||
      login.length > 256 ||
      password.length > 256
    ) {
      throw new Error(
        "SOUNDCLOUD_PROXY_URL must use a valid IPv4 ip:port:login:password"
      );
    }
    return `http://${encodeURIComponent(login)}:${encodeURIComponent(password)}@${ip}:${port}`;
  }

  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error("SOUNDCLOUD_PROXY_URL must be an absolute proxy URL");
  }
  if (!["http:", "https:"].includes(url.protocol)) {
    throw new Error("SOUNDCLOUD_PROXY_URL must use http or https");
  }
  if (isIP(url.hostname) !== 4 || url.hash || url.search) {
    throw new Error("SOUNDCLOUD_PROXY_URL must use a literal IPv4 address");
  }
  return url.toString();
}

function createProxyAgent(value?: string) {
  const proxyUrl = normalizeProxyUrl(value);
  return proxyUrl ? new ProxyAgent(proxyUrl) : undefined;
}

function normalizeUserCredential(value?: string): SoundCloudCredential | undefined {
  if (value === undefined) return undefined;
  const raw = value.trim();
  if (!raw || raw.length > 4_096 || /[\r\n]/.test(raw)) {
    throw new ProviderGatewayError(
      "INVALID_PROVIDER_TOKEN",
      "The SoundCloud credential is invalid",
      401
    );
  }
  if (/^2-\d+-\d+-/.test(raw)) {
    throw new ProviderGatewayError(
      "INVALID_PROVIDER_TOKEN",
      "SoundCloud oauth_token cookie is not an API credential; use Client ID",
      401
    );
  }
  const withoutPrefix = raw.replace(/^(?:OAuth|Bearer)\s+/i, "");
  const clientId = normalizeClientId(withoutPrefix, false);
  return clientId
    ? { kind: "client_id", value: clientId }
    : { kind: "oauth", value: withoutPrefix };
}

function withoutBrowserCookie(access?: ProviderAccess) {
  if (!/^2-\d+-\d+-/.test(access?.token?.trim() ?? "")) return access;
  return { ...access, token: undefined };
}

function normalizeClientId(value?: string, strict = true) {
  const raw = value?.trim();
  if (!raw) return undefined;
  if (/^[A-Za-z0-9_-]{32}$/.test(raw)) return raw;
  if (strict) {
    throw new ProviderGatewayError(
      "INVALID_PROVIDER_TOKEN",
      "The SoundCloud Client ID is invalid",
      401
    );
  }
  return undefined;
}

function normalizeTrackUrn(value: string) {
  return /^\d+$/.test(value) ? `soundcloud:tracks:${value}` : value;
}

function normalizeTrackId(value: string) {
  return value.replace(/^soundcloud:tracks:/, "");
}

function selectTranscoding(
  transcodings: SoundCloudTranscoding[],
  quality: AudioQuality
) {
  const playable = transcodings.filter(
    (item) =>
      item.format.protocol === "hls" ||
      item.format.protocol === "progressive"
  );
  const priorities =
    quality === "low"
      ? [
          (item: SoundCloudTranscoding) =>
            item.format.protocol === "hls" &&
            item.format.mime_type.includes("audio/mpeg"),
          (item: SoundCloudTranscoding) => item.format.protocol === "hls"
        ]
      : [
          (item: SoundCloudTranscoding) =>
            item.format.protocol === "progressive" &&
            item.format.mime_type.includes("audio/mpeg"),
          (item: SoundCloudTranscoding) =>
            item.format.protocol === "progressive",
          (item: SoundCloudTranscoding) =>
            item.format.protocol === "hls" &&
            item.format.mime_type.includes("audio/mpeg"),
          (item: SoundCloudTranscoding) => item.format.protocol === "hls"
        ];
  for (const predicate of priorities) {
    const match = playable.find(predicate);
    if (match) return match;
  }
  return playable[0];
}

function codecFromMimeType(value: string) {
  if (/mp4|aac|mp4a/i.test(value)) return "aac";
  if (/mpeg|mp3/i.test(value)) return "mp3";
  return undefined;
}

export function assertAllowedStreamUrl(value: string) {
  const url = new URL(value);
  const allowed = ["sndcdn.com", "soundcloud.cloud", "soundcloud.com"];
  if (
    url.protocol !== "https:" ||
    !allowed.some(
      (domain) =>
        url.hostname === domain || url.hostname.endsWith(`.${domain}`)
    )
  ) {
    throw new ProviderGatewayError(
      "UPSTREAM_ERROR",
      "SoundCloud returned an unexpected stream host",
      502
    );
  }
}

function parseStreamExpiry(value: string) {
  const url = new URL(value);
  for (const key of ["Expires", "expires", "exp"]) {
    const raw = url.searchParams.get(key);
    if (!raw) continue;
    const numeric = Number(raw);
    if (Number.isFinite(numeric)) {
      return new Date(
        numeric > 10_000_000_000 ? numeric : numeric * 1000
      ).toISOString();
    }
  }
  return undefined;
}
