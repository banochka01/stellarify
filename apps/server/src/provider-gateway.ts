export type ProviderName = "soundcloud" | "yandex" | "youtube";
export type AudioQuality = "low" | "medium" | "high" | "lossless";

export interface ProviderAccess {
  token?: string;
  cacheScope?: string;
  useProxy?: boolean;
}

export interface ProviderTrack {
  id: string;
  title: string;
  artist: string;
  album?: string;
  durationMs?: number;
  artworkUrl?: string;
  externalUrl: string;
}

export interface ResolvedStream {
  streamUrl: string;
  protocol: "progressive" | "hls" | "dash";
  codec?: string;
  bitrate?: number;
  expiresAt?: string;
  headers?: Record<string, string>;
}

export interface MusicProviderAdapter {
  readonly name: ProviderName;
  readonly configured: boolean;
  readonly serverCredentialConfigured?: boolean;
  readonly directPlayback?: boolean;
  readonly authentication:
    | "server_credentials"
    | "user_token"
    | "user_token_or_server_credentials";
  readonly proxyAvailable?: boolean;
  validateAccess?(access?: ProviderAccess): Promise<void>;
  searchTracks(
    query: string,
    limit: number,
    access?: ProviderAccess
  ): Promise<ProviderTrack[]>;
  resolve(
    externalId: string,
    quality: AudioQuality,
    access?: ProviderAccess
  ): Promise<ResolvedStream>;
}

export type GatewayErrorCode =
  | "PROVIDER_NOT_CONFIGURED"
  | "PROVIDER_NOT_SUPPORTED"
  | "PROVIDER_AUTH_REQUIRED"
  | "INVALID_PROVIDER_TOKEN"
  | "PROVIDER_ACCESS_DENIED"
  | "PROVIDER_RATE_LIMITED"
  | "PROXY_NOT_CONFIGURED"
  | "PROXY_CONNECTION_FAILED"
  | "TRACK_NOT_FOUND"
  | "STREAM_UNAVAILABLE"
  | "UPSTREAM_ERROR"
  | "UPSTREAM_TIMEOUT";

export class ProviderGatewayError extends Error {
  constructor(
    readonly code: GatewayErrorCode,
    message: string,
    readonly status: number,
    options?: ErrorOptions
  ) {
    super(message, options);
    this.name = "ProviderGatewayError";
  }
}

type CachedStream = { value: ResolvedStream; validUntil: number };

export class ProviderGateway {
  private readonly adapters = new Map<ProviderName, MusicProviderAdapter>();
  private readonly streamCache = new Map<string, CachedStream>();

  constructor(
    adapters: MusicProviderAdapter[],
    private readonly now: () => number = Date.now,
    private readonly maxCacheEntries = 500
  ) {
    for (const adapter of adapters) {
      this.adapters.set(adapter.name, adapter);
    }
  }

  listProviders() {
    return [...this.adapters.values()].map(
      ({ name, configured, authentication, proxyAvailable, directPlayback, serverCredentialConfigured }) => ({
        name,
        configured,
        authentication,
        serverCredentialConfigured: serverCredentialConfigured ?? false,
        proxyAvailable: proxyAvailable ?? false,
        capabilities: { search: true, playback: directPlayback !== false }
      })
    );
  }

  async validate(provider: ProviderName, access?: ProviderAccess) {
    const adapter = this.getAdapter(provider);
    if (!adapter.validateAccess) {
      throw new ProviderGatewayError(
        "PROVIDER_NOT_SUPPORTED",
        `Provider ${provider} does not support token validation`,
        400
      );
    }
    await adapter.validateAccess(access);
  }

  async search(
    provider: ProviderName,
    query: string,
    limit: number,
    access?: ProviderAccess
  ) {
    return this.getAdapter(provider).searchTracks(query, limit, access);
  }

  async resolve(
    provider: ProviderName,
    externalId: string,
    quality: AudioQuality,
    access?: ProviderAccess
  ) {
    const cacheKey = `${provider}:${access?.cacheScope ?? "shared"}:${externalId}:${quality}`;
    const cached = this.streamCache.get(cacheKey);
    if (cached && cached.validUntil > this.now()) {
      return cached.value;
    }
    if (cached) this.streamCache.delete(cacheKey);

    const stream = await this.getAdapter(provider).resolve(
      externalId,
      quality,
      access
    );
    const declaredExpiry = stream.expiresAt
      ? Date.parse(stream.expiresAt)
      : Number.NaN;
    const defaultExpiry = this.now() + 3 * 60_000;
    const validUntil = Number.isFinite(declaredExpiry)
      ? Math.min(declaredExpiry - 15_000, defaultExpiry)
      : defaultExpiry;

    if (validUntil > this.now()) {
      if (this.streamCache.size >= this.maxCacheEntries) {
        const oldest = this.streamCache.keys().next().value;
        if (oldest) this.streamCache.delete(oldest);
      }
      this.streamCache.set(cacheKey, { value: stream, validUntil });
    }
    return stream;
  }

  private getAdapter(provider: ProviderName) {
    const adapter = this.adapters.get(provider);
    if (!adapter) {
      throw new ProviderGatewayError(
        "PROVIDER_NOT_SUPPORTED",
        `Provider ${provider} is not supported`,
        400
      );
    }
    if (!adapter.configured) {
      throw new ProviderGatewayError(
        "PROVIDER_NOT_CONFIGURED",
        `Provider ${provider} is not configured`,
        503
      );
    }
    return adapter;
  }
}
