import {
  type AudioQuality,
  type MusicProviderAdapter,
  type ProviderAccess,
  type ProviderTrack,
  ProviderGatewayError,
  type ResolvedStream
} from "./provider-gateway.js";

type FetchLike = typeof fetch;

export type ImportedPlaylist = {
  provider: "youtube" | "yandex";
  externalId: string;
  title: string;
  artworkUrl?: string;
  tracks: ProviderTrack[];
};

export class YouTubeAdapter implements MusicProviderAdapter {
  readonly name = "youtube" as const;
  readonly authentication = "user_token_or_server_credentials" as const;
  readonly configured = true;
  readonly directPlayback = false;

  get serverCredentialConfigured() {
    return Boolean(this.defaultApiKey?.trim());
  }

  constructor(
    private readonly defaultApiKey?: string,
    private readonly request: FetchLike = fetch
  ) {}

  async validateAccess(access?: ProviderAccess): Promise<void> {
    await this.get("videos", {
      part: "id",
      id: "dQw4w9WgXcQ",
      maxResults: "1"
    }, access);
  }

  async searchTracks(query: string, limit: number, access?: ProviderAccess) {
    const data = await this.get("search", {
      part: "snippet",
      type: "video",
      videoCategoryId: "10",
      q: query,
      maxResults: String(Math.min(limit, 50))
    }, access);
    return array(data.items).flatMap((raw) => {
      const item = object(raw);
      const id = object(item.id).videoId;
      return typeof id === "string" ? [mapVideo(id, object(item.snippet))] : [];
    });
  }

  async importPlaylist(playlistId: string, access?: ProviderAccess): Promise<ImportedPlaylist> {
    if (!/^[A-Za-z0-9_-]{8,160}$/.test(playlistId)) {
      throw new ProviderGatewayError("TRACK_NOT_FOUND", "Invalid YouTube playlist id", 404);
    }
    const metadata = await this.get("playlists", {
      part: "snippet",
      id: playlistId,
      maxResults: "1"
    }, access);
    const playlistItem = array(metadata.items)[0];
    if (!playlistItem) {
      throw new ProviderGatewayError("TRACK_NOT_FOUND", "YouTube playlist was not found", 404);
    }
    const snippet = object(object(playlistItem).snippet);
    const tracks: ProviderTrack[] = [];
    let pageToken: string | undefined;
    do {
      const page = await this.get("playlistItems", {
        part: "snippet,contentDetails",
        playlistId,
        maxResults: "50",
        ...(pageToken ? { pageToken } : {})
      }, access);
      for (const raw of array(page.items)) {
        const item = object(raw);
        const videoId = object(item.contentDetails).videoId;
        if (typeof videoId === "string") tracks.push(mapVideo(videoId, object(item.snippet)));
      }
      pageToken = typeof page.nextPageToken === "string" ? page.nextPageToken : undefined;
    } while (pageToken && tracks.length < 500);

    return {
      provider: "youtube",
      externalId: playlistId,
      title: string(snippet.title) || "YouTube playlist",
      artworkUrl: thumbnail(snippet),
      tracks: tracks.slice(0, 500)
    };
  }

  async resolve(_externalId: string, _quality: AudioQuality, _access?: ProviderAccess): Promise<ResolvedStream> {
    throw new ProviderGatewayError(
      "PROVIDER_NOT_SUPPORTED",
      "YouTube cannot be played by the native Resonance player",
      400
    );
  }

  private async get(path: string, parameters: Record<string, string>, access?: ProviderAccess) {
    const key = access?.token?.trim() || this.defaultApiKey?.trim();
    if (!key) {
      throw new ProviderGatewayError("PROVIDER_AUTH_REQUIRED", "A YouTube Data API key is required", 401);
    }
    if (!/^[A-Za-z0-9_-]{20,200}$/.test(key)) {
      throw new ProviderGatewayError("INVALID_PROVIDER_TOKEN", "The YouTube API key is invalid", 401);
    }
    const url = new URL(`https://www.googleapis.com/youtube/v3/${path}`);
    url.search = new URLSearchParams({ ...parameters, key }).toString();
    let response: Response;
    try {
      response = await this.request(url, { signal: AbortSignal.timeout(12_000) });
    } catch (error) {
      throw new ProviderGatewayError("UPSTREAM_TIMEOUT", "YouTube did not respond", 502, { cause: error });
    }
    if (!response.ok) {
      throw new ProviderGatewayError(
        response.status === 400 || response.status === 403 ? "INVALID_PROVIDER_TOKEN" : "UPSTREAM_ERROR",
        response.status === 404 ? "YouTube playlist was not found" : "YouTube Data API rejected the request",
        response.status === 404 ? 404 : response.status === 400 || response.status === 403 ? 401 : 502
      );
    }
    return object(await response.json());
  }
}

const mapVideo = (id: string, snippet: Record<string, unknown>): ProviderTrack => ({
  id,
  title: string(snippet.title) || "YouTube video",
  artist: string(snippet.videoOwnerChannelTitle) || string(snippet.channelTitle) || "YouTube",
  artworkUrl: thumbnail(snippet),
  externalUrl: `https://www.youtube.com/watch?v=${encodeURIComponent(id)}`
});

const thumbnail = (snippet: Record<string, unknown>) => {
  const thumbnails = object(snippet.thumbnails);
  for (const key of ["maxres", "standard", "high", "medium", "default"]) {
    const url = object(thumbnails[key]).url;
    if (typeof url === "string" && url.startsWith("https://")) return url;
  }
  return undefined;
};

const object = (value: unknown): Record<string, any> => value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, any> : {};
const array = (value: unknown): unknown[] => Array.isArray(value) ? value : [];
const string = (value: unknown): string | undefined => typeof value === "string" && value.trim() ? value.trim() : undefined;
