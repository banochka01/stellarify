import {
  type AudioQuality,
  type MusicProviderAdapter,
  type ProviderAccess,
  type ProviderTrack,
  ProviderGatewayError,
  type ResolvedStream
} from "./provider-gateway.js";

type FetchLike = typeof fetch;

const apiBase = "https://api.vk.com/method";
const apiVersion = "5.199";
const maxSearchCount = 100;
const maxPageCount = 300;

/** VK serves audio files from userapi CDN hosts; everything else is rejected. */
const streamHostSuffixes = ["userapi.com", "vkuseraudio.net", "vk-cdn.net", "vk.com", "vk.ru"];

export type VkImportedPlaylist = {
  provider: "vk";
  externalId: string;
  title: string;
  artworkUrl?: string;
  tracks: ProviderTrack[];
};

export class VkAdapter implements MusicProviderAdapter {
  readonly name = "vk" as const;
  readonly authentication = "user_token_or_server_credentials" as const;
  readonly configured = true;
  readonly directPlayback = true;

  get serverCredentialConfigured() {
    return Boolean(this.defaultToken?.trim());
  }

  constructor(
    private readonly defaultToken?: string,
    private readonly request: FetchLike = fetch,
    private readonly now: () => number = Date.now
  ) {}

  async validateAccess(access?: ProviderAccess): Promise<void> {
    await this.searchTracks("Resonance", 1, access);
  }

  async searchTracks(
    query: string,
    limit: number,
    access?: ProviderAccess
  ): Promise<ProviderTrack[]> {
    const data = await this.call(
      "audio.search",
      {
        q: query,
        count: String(Math.min(limit, maxSearchCount)),
        search_own: "0"
      },
      access
    );
    const items = array(object(object(data.response)).items);
    return items
      .map((raw) => mapVkTrack(object(raw)))
      .filter((track): track is ProviderTrack => track !== undefined)
      .slice(0, limit);
  }

  async resolve(
    externalId: string,
    _quality: AudioQuality,
    access?: ProviderAccess
  ): Promise<ResolvedStream> {
    const id = normalizeVkTrackId(externalId);
    const data = await this.call("audio.getById", { ids: id }, access);
    const payload = data.response;
    const items = array(
      Array.isArray(payload) ? payload : object(payload).items
    );
    const track = items.length ? object(items[0]) : undefined;
    const streamUrl = string(track?.url);
    if (!track || !streamUrl) {
      throw new ProviderGatewayError(
        "STREAM_UNAVAILABLE",
        "VK did not return a stream URL for this track",
        404
      );
    }
    assertAllowedVkStreamUrl(streamUrl);
    return {
      streamUrl,
      protocol: "progressive",
      codec: "mp3",
      bitrate: 320_000
    };
  }

  async importPlaylist(reference: { owner: string; playlist: string }, access?: ProviderAccess): Promise<VkImportedPlaylist> {
    if (!/^-?\d+$/.test(reference.owner) || !/^\d+$/.test(reference.playlist)) {
      throw new ProviderGatewayError("TRACK_NOT_FOUND", "Invalid VK playlist reference", 400);
    }
    const tracks: ProviderTrack[] = [];
    let offset = 0;
    let total = Number.POSITIVE_INFINITY;
    do {
      const data = await this.call(
        "audio.get",
        {
          owner_id: reference.owner,
          playlist_id: reference.playlist,
          count: String(maxPageCount),
          offset: String(offset)
        },
        access
      );
      const response = object(data.response);
      const items = array(response.items);
      total = Number.isFinite(Number(response.count)) ? Number(response.count) : items.length;
      for (const raw of items) {
        const track = mapVkTrack(object(raw));
        if (track) tracks.push(track);
      }
      offset += items.length;
    } while (tracks.length < 500 && offset < total && offset > 0);

    if (!tracks.length) {
      throw new ProviderGatewayError("TRACK_NOT_FOUND", "VK playlist is empty or was not found", 404);
    }

    return {
      provider: "vk",
      externalId: `${reference.owner}_${reference.playlist}`,
      title: `VK плейлист ${reference.owner}_${reference.playlist}`,
      tracks: tracks.slice(0, 500)
    };
  }

  private async call(
    method: string,
    parameters: Record<string, string>,
    access?: ProviderAccess
  ) {
    const token = access?.token?.trim() || this.defaultToken?.trim();
    if (!token) {
      throw new ProviderGatewayError(
        "PROVIDER_AUTH_REQUIRED",
        "A VK access token with audio permissions is required",
        401
      );
    }
    if (token.length > 4_096 || /[\r\n]/.test(token)) {
      throw new ProviderGatewayError("INVALID_PROVIDER_TOKEN", "The VK access token is invalid", 401);
    }
    const url = new URL(`${apiBase}/${method}`);
    url.search = new URLSearchParams({
      ...parameters,
      access_token: token,
      v: apiVersion
    }).toString();

    let response: Response;
    try {
      response = await this.request(url, {
        headers: { accept: "application/json" },
        signal: AbortSignal.timeout(12_000)
      });
    } catch (error) {
      const timedOut = error instanceof Error && error.name === "TimeoutError";
      throw new ProviderGatewayError(
        timedOut ? "UPSTREAM_TIMEOUT" : "UPSTREAM_ERROR",
        timedOut ? "VK did not respond in time" : "VK request failed",
        502,
        { cause: error }
      );
    }
    if (!response.ok) {
      throw new ProviderGatewayError("UPSTREAM_ERROR", `VK returned HTTP ${response.status}`, 502);
    }
    const payload = object(await response.json());
    const vkError = object(payload.error);
    if (vkError.error_code !== undefined) {
      throw mapVkApiError(vkError.error_code, string(vkError.error_msg));
    }
    return payload;
  }
}

export function mapVkTrack(raw: Record<string, unknown>): ProviderTrack | undefined {
  const id = Number(raw.id);
  const ownerId = Number(raw.owner_id);
  const title = string(raw.title);
  const artist = string(raw.artist) ?? string(raw.performer);
  if (!Number.isInteger(id) || !Number.isInteger(ownerId) || !title || !artist) {
    return undefined;
  }
  const album = object(raw.album);
  const durationSeconds = Number(raw.duration);
  return {
    id: `vk:audio:${ownerId}_${id}`,
    title,
    artist,
    album: string(album.title),
    durationMs: Number.isFinite(durationSeconds) ? durationSeconds * 1_000 : undefined,
    artworkUrl: pickArtwork(object(album.thumb)) ?? pickArtwork(object(raw.thumb)),
    externalUrl: `https://vk.com/audio${ownerId}_${id}`
  };
}

export function normalizeVkTrackId(value: string) {
  const trimmed = value.trim();
  const match = /^vk:audio:(-?\d+_\d+)$/.exec(trimmed);
  if (match) return match[1]!;
  return trimmed;
}

export function assertAllowedVkStreamUrl(value: string) {
  const url = new URL(value);
  if (
    url.protocol !== "https:" ||
    !streamHostSuffixes.some(
      (suffix) => url.hostname === suffix || url.hostname.endsWith(`.${suffix}`)
    )
  ) {
    throw new ProviderGatewayError("UPSTREAM_ERROR", "VK returned an unexpected stream host", 502);
  }
}

/** Accepts https://vk.com/music/playlist/1_2 and https://vk.com/audio_playlist1_2 forms. */
export function parseVkPlaylistReference(pathname: string): { owner: string; playlist: string } | undefined {
  const segments = pathname.split("/").filter(Boolean);
  const playlistSegment = segments.find((segment) => segment === "playlist");
  if (playlistSegment) {
    const index = segments.indexOf(playlistSegment);
    const reference = segments[index + 1];
    const match = /^(-?\d+)_(\d+)$/.exec(reference ?? "");
    if (match) return { owner: match[1]!, playlist: match[2]! };
  }
  const legacy = /^audio_playlist(-?\d+)_(\d+)$/.exec(segments[segments.length - 1] ?? "");
  if (legacy) return { owner: legacy[1]!, playlist: legacy[2]! };
  return undefined;
}

function mapVkApiError(code: unknown, message?: string) {
  const numeric = Number(code);
  if (numeric === 5 || numeric === 10 || numeric === 20 || numeric === 28) {
    return new ProviderGatewayError("INVALID_PROVIDER_TOKEN", "The VK access token was rejected", 401);
  }
  if (numeric === 6 || numeric === 9 || numeric === 10) {
    return new ProviderGatewayError("PROVIDER_RATE_LIMITED", "VK rate limit exceeded", 429);
  }
  if (numeric === 15 || numeric === 17 || numeric === 300) {
    return new ProviderGatewayError(
      "PROVIDER_ACCESS_DENIED",
      "VK denied audio access for this token",
      403
    );
  }
  if (numeric === 100) {
    return new ProviderGatewayError("TRACK_NOT_FOUND", message || "VK rejected the request parameters", 400);
  }
  return new ProviderGatewayError("UPSTREAM_ERROR", message || `VK API error ${numeric}`, 502);
}

function pickArtwork(thumb: Record<string, unknown>) {
  for (const key of ["photo_1200", "photo_600", "photo_300", "photo_100"]) {
    const url = string(thumb[key]);
    if (url?.startsWith("https://")) return url;
  }
  return undefined;
}

const object = (value: unknown): Record<string, any> =>
  value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, any>) : {};
const array = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);
const string = (value: unknown): string | undefined =>
  typeof value === "string" && value.trim() ? value.trim() : undefined;
