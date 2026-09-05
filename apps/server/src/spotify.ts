import {
  type AudioQuality,
  type MusicProviderAdapter,
  type ProviderAccess,
  type ProviderTrack,
  ProviderGatewayError,
  type ResolvedStream
} from "./provider-gateway.js";

type FetchLike = typeof fetch;

interface SpotifyCredentials {
  clientId?: string;
  clientSecret?: string;
}

export type SpotifyImportedPlaylist = {
  provider: "spotify";
  externalId: string;
  title: string;
  artworkUrl?: string;
  tracks: ProviderTrack[];
};

interface SpotifyTokenCacheEntry {
  token: string;
  validUntil: number;
}

const apiBase = "https://api.spotify.com/v1";
const accountsBase = "https://accounts.spotify.com/api/token";

/** Official 30-second preview MP3s served by the Spotify CDN. */
const previewHostSuffixes = ["scdn.co", "spotifycdn.com"];

export class SpotifyAdapter implements MusicProviderAdapter {
  readonly name = "spotify" as const;
  readonly authentication = "user_token_or_server_credentials" as const;
  readonly configured = true;
  readonly directPlayback = true;

  get serverCredentialConfigured() {
    return Boolean(this.credentials.clientId?.trim() && this.credentials.clientSecret?.trim());
  }

  private appToken?: SpotifyTokenCacheEntry;

  constructor(
    private readonly credentials: SpotifyCredentials,
    private readonly request: FetchLike = fetch,
    private readonly now: () => number = Date.now
  ) {}

  async validateAccess(access?: ProviderAccess): Promise<void> {
    await this.apiGet(
      new URL(`${apiBase}/search`),
      {
        q: "Resonance",
        type: "track",
        limit: "1"
      },
      access
    );
  }

  async searchTracks(
    query: string,
    limit: number,
    access?: ProviderAccess
  ): Promise<ProviderTrack[]> {
    const data = await this.apiGet(
      new URL(`${apiBase}/search`),
      {
        q: query,
        type: "track",
        limit: String(Math.min(limit, 50))
      },
      access
    );
    const items = array(object(object(data.tracks).items));
    return items.flatMap((raw) => {
      const track = mapSpotifyTrack(object(raw));
      return track ? [track] : [];
    });
  }

  async importPlaylist(playlistId: string, access?: ProviderAccess): Promise<SpotifyImportedPlaylist> {
    if (!/^[A-Za-z0-9]{16,32}$/.test(playlistId)) {
      throw new ProviderGatewayError("TRACK_NOT_FOUND", "Invalid Spotify playlist id", 400);
    }
    let metadata: Record<string, unknown>;
    try {
      metadata = object(
        await this.apiGet(new URL(`${apiBase}/playlists/${encodeURIComponent(playlistId)}`), {}, access)
      );
    } catch (error) {
      if (error instanceof ProviderGatewayError && error.code === "TRACK_NOT_FOUND") {
        throw new ProviderGatewayError("TRACK_NOT_FOUND", "Spotify playlist was not found", 404);
      }
      throw error;
    }

    const tracks: ProviderTrack[] = [];
    let next = string(object(object(metadata.tracks)).next);
    let first = true;
    do {
      const page = first ? object(object(metadata.tracks)) : object(await this.apiGetUrl(next!, access));
      first = false;
      for (const raw of array(page.items)) {
        const track = mapSpotifyTrack(object(object(raw).track));
        if (track) tracks.push(track);
      }
      next = string(page.next);
    } while (next && tracks.length < 500);

    return {
      provider: "spotify",
      externalId: playlistId,
      title: string(metadata.name) || "Spotify playlist",
      artworkUrl: pickImage(array(metadata.images)),
      tracks: tracks.slice(0, 500)
    };
  }

  async resolve(
    externalId: string,
    _quality: AudioQuality,
    access?: ProviderAccess
  ): Promise<ResolvedStream> {
    const id = normalizeSpotifyTrackId(externalId);
    const data = object(
      await this.apiGet(new URL(`${apiBase}/tracks/${encodeURIComponent(id)}`), {}, access)
    );
    const previewUrl = string(data.preview_url);
    if (!previewUrl) {
      throw new ProviderGatewayError(
        "STREAM_UNAVAILABLE",
        "Spotify did not return a preview stream for this track",
        404
      );
    }
    assertAllowedPreviewUrl(previewUrl);
    return {
      streamUrl: previewUrl,
      protocol: "progressive",
      codec: "mp3",
      bitrate: 96_000,
      preview: true
    };
  }

  private async apiGet(
    url: URL,
    parameters: Record<string, string>,
    access?: ProviderAccess
  ) {
    for (const [key, value] of Object.entries(parameters)) {
      url.searchParams.set(key, value);
    }
    const token = await this.resolveToken(access);
    return this.requestJson(url, token);
  }

  private async apiGetUrl(value: string, access?: ProviderAccess) {
    return this.requestJson(new URL(value), await this.resolveToken(access));
  }

  private async resolveToken(access?: ProviderAccess): Promise<string> {
    const userToken = access?.token?.trim();
    if (userToken) {
      if (userToken.length > 4_096 || /[\r\n]/.test(userToken)) {
        throw new ProviderGatewayError("INVALID_PROVIDER_TOKEN", "The Spotify access token is invalid", 401);
      }
      return userToken;
    }
    return this.appAccessToken();
  }

  private async appAccessToken(): Promise<string> {
    const cached = this.appToken;
    if (cached && cached.validUntil > this.now() + 30_000) {
      return cached.token;
    }
    const clientId = this.credentials.clientId?.trim();
    const clientSecret = this.credentials.clientSecret?.trim();
    if (!clientId || !clientSecret) {
      throw new ProviderGatewayError(
        "PROVIDER_AUTH_REQUIRED",
        "Spotify client credentials are not configured",
        401
      );
    }

    let response: Response;
    try {
      response = await this.request(accountsBase, {
        method: "POST",
        headers: {
          "content-type": "application/x-www-form-urlencoded",
          authorization: `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString("base64")}`
        },
        body: "grant_type=client_credentials",
        signal: AbortSignal.timeout(8_000)
      });
    } catch (error) {
      throw new ProviderGatewayError("UPSTREAM_TIMEOUT", "Spotify accounts service did not respond", 502, {
        cause: error
      });
    }
    if (response.status === 400 || response.status === 401) {
      throw new ProviderGatewayError("INVALID_PROVIDER_TOKEN", "Spotify rejected the client credentials", 401);
    }
    if (!response.ok) {
      throw new ProviderGatewayError("UPSTREAM_ERROR", `Spotify accounts returned HTTP ${response.status}`, 502);
    }
    const payload = object(await response.json());
    const token = string(payload.access_token);
    const expiresIn = Number(payload.expires_in);
    if (!token || !Number.isFinite(expiresIn)) {
      throw new ProviderGatewayError("UPSTREAM_ERROR", "Spotify returned an invalid token payload", 502);
    }
    this.appToken = { token, validUntil: this.now() + expiresIn * 1_000 };
    return token;
  }

  private async requestJson(url: URL, token: string) {
    if (url.origin !== "https://api.spotify.com") {
      throw new ProviderGatewayError("UPSTREAM_ERROR", "Spotify returned an unexpected pagination host", 502);
    }
    let response: Response;
    try {
      response = await this.request(url, {
        headers: { accept: "application/json", authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(12_000)
      });
    } catch (error) {
      throw new ProviderGatewayError("UPSTREAM_TIMEOUT", "Spotify did not respond", 502, { cause: error });
    }
    if (response.status === 401) {
      this.appToken = undefined;
      throw new ProviderGatewayError("INVALID_PROVIDER_TOKEN", "The Spotify access token was rejected", 401);
    }
    if (response.status === 429) {
      throw new ProviderGatewayError("PROVIDER_RATE_LIMITED", "Spotify rate limit exceeded", 429);
    }
    if (response.status === 404) {
      throw new ProviderGatewayError("TRACK_NOT_FOUND", "Spotify track was not found", 404);
    }
    if (!response.ok) {
      throw new ProviderGatewayError("UPSTREAM_ERROR", `Spotify returned HTTP ${response.status}`, 502);
    }
    return object(await response.json());
  }
}

export function mapSpotifyTrack(raw: Record<string, unknown>): ProviderTrack | undefined {
  const id = string(raw.id);
  const title = string(raw.name);
  const artists = array(raw.artists);
  const artist = artists
    .map((entry) => string(object(entry).name))
    .filter((name): name is string => Boolean(name))
    .join(", ");
  const externalUrl = string(object(object(raw.external_urls)).spotify);
  if (!id || !title || !artist || !externalUrl) return undefined;
  const album = object(raw.album);
  return {
    id: `spotify:track:${id}`,
    title,
    artist,
    album: string(album.name),
    durationMs: Number.isFinite(Number(raw.duration_ms)) ? Number(raw.duration_ms) : undefined,
    artworkUrl: pickImage(array(album.images)),
    externalUrl
  };
}

export function normalizeSpotifyTrackId(value: string) {
  const match = /^spotify:track:([A-Za-z0-9]+)$/.exec(value.trim());
  if (match) return match[1]!;
  if (/^https?:\/\/open\.spotify\.com\/track\/([A-Za-z0-9]+)/.test(value.trim())) {
    return value.trim().split("/track/")[1]!.split("?")[0]!;
  }
  return value.trim();
}

export function assertAllowedPreviewUrl(value: string) {
  const url = new URL(value);
  if (
    url.protocol !== "https:" ||
    !previewHostSuffixes.some(
      (suffix) => url.hostname === suffix || url.hostname.endsWith(`.${suffix}`)
    )
  ) {
    throw new ProviderGatewayError(
      "UPSTREAM_ERROR",
      "Spotify returned an unexpected preview host",
      502
    );
  }
}

function pickImage(images: unknown[]) {
  for (const raw of images) {
    const url = string(object(raw).url);
    if (url?.startsWith("https://")) return url;
  }
  return undefined;
}

const object = (value: unknown): Record<string, any> =>
  value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, any>) : {};
const array = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);
const string = (value: unknown): string | undefined =>
  typeof value === "string" && value.trim() ? value.trim() : undefined;
