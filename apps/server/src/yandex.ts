import { Client } from "@dvxch/yandex-music";
import {
  type AudioQuality,
  type MusicProviderAdapter,
  type ProviderAccess,
  type ProviderTrack,
  ProviderGatewayError,
  type ResolvedStream
} from "./provider-gateway.js";
import type { ImportedPlaylist } from "./youtube.js";

interface YandexTrackLike {
  id?: string | number;
  title?: string;
  available?: boolean;
  artists?: Array<{ name?: string }>;
  albums?: Array<{ title?: string }>;
  coverUri?: string;
  durationMs?: number;
}

interface YandexDownloadInfoLike {
  codec?: string;
  bitrateInKbps?: number;
  preview?: boolean;
  direct?: boolean;
  downloadInfoUrl?: string;
  getDirectLink(): Promise<string>;
}

interface YandexClientLike {
  search(
    text: string,
    nocorrect?: boolean,
    type?: "track",
    page?: number
  ): Promise<{ tracks?: { results?: YandexTrackLike[] } } | null>;
  tracksDownloadInfo(trackId: string): Promise<YandexDownloadInfoLike[]>;
  usersPlaylists?(kind: string | number, userId?: string | number): Promise<YandexPlaylistLike | YandexPlaylistLike[] | null>;
  playlist?(playlistUuid: string): Promise<YandexPlaylistLike | null>;
  tracks?(trackIds: Array<string | number> | string | number): Promise<YandexTrackLike[]>;
}

interface YandexPlaylistLike {
  title?: string;
  playlistUuid?: string;
  kind?: number;
  uid?: number;
  coverUri?: string;
  image?: string;
  tracks?: Array<{ id?: string | number; track?: YandexTrackLike }>;
}

type YandexClientFactory = (token: string) => YandexClientLike;

export class YandexAdapter implements MusicProviderAdapter {
  readonly name = "yandex" as const;
  readonly authentication = "user_token_or_server_credentials" as const;
  readonly configured = true;

  get serverCredentialConfigured() {
    return Boolean(this.defaultToken?.trim());
  }

  constructor(
    private readonly defaultToken?: string,
    private readonly clientFactory: YandexClientFactory = (token) =>
      new Client({ token, retries: 1 }),
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
    const client = this.client(access);
    try {
      const result = await client.search(query, false, "track", 0);
      return (result?.tracks?.results ?? [])
        .filter((track): track is YandexTrackLike & { id: string | number; title: string } => track !== undefined && isPlayableTrack(track))
        .slice(0, limit)
        .map(mapTrack);
    } catch (error) {
      throw mapYandexError(error);
    }
  }

  async resolve(
    externalId: string,
    quality: AudioQuality,
    access?: ProviderAccess
  ): Promise<ResolvedStream> {
    if (!/^\d+(?::\d+)?$/.test(externalId)) {
      throw new ProviderGatewayError(
        "TRACK_NOT_FOUND",
        "Invalid Yandex Music track id",
        404
      );
    }

    const client = this.client(access);
    try {
      const variants = (await client.tracksDownloadInfo(externalId)).filter(
        (item) =>
          !item.preview &&
          Boolean(item.downloadInfoUrl) &&
          (item.codec === "mp3" || item.codec === "aac")
      );
      const selected = selectVariant(variants, quality);
      if (!selected?.downloadInfoUrl) {
        throw new ProviderGatewayError(
          "STREAM_UNAVAILABLE",
          "Yandex Music did not return a full playable stream",
          404
        );
      }

      const streamUrl = selected.direct
        ? selected.downloadInfoUrl
        : await selected.getDirectLink();
      assertAllowedYandexStreamUrl(streamUrl);
      const isHls = new URL(streamUrl).pathname.endsWith(".m3u8");
      return {
        streamUrl,
        protocol: isHls ? "hls" : "progressive",
        codec: selected.codec,
        bitrate: selected.bitrateInKbps
          ? selected.bitrateInKbps * 1000
          : undefined,
        expiresAt: new Date(this.now() + 45_000).toISOString()
      };
    } catch (error) {
      if (error instanceof ProviderGatewayError) throw error;
      throw mapYandexError(error);
    }
  }

  async importPlaylist(reference: { owner?: string; kind?: string; uuid?: string }, access?: ProviderAccess): Promise<ImportedPlaylist> {
    const client = this.client(access);
    try {
      const rawPlaylist = reference.uuid && client.playlist
        ? await client.playlist(reference.uuid)
        : reference.kind && client.usersPlaylists
          ? await client.usersPlaylists(reference.kind, reference.owner)
          : null;
      const playlist = Array.isArray(rawPlaylist) ? rawPlaylist[0] : rawPlaylist;
      if (!playlist) throw new ProviderGatewayError("TRACK_NOT_FOUND", "Yandex playlist was not found", 404);
      const rawTracks = playlist.tracks ?? [];
      const missingIds = rawTracks.filter((item) => !item.track && item.id != null).map((item) => item.id!);
      const fetched = missingIds.length && client.tracks ? await client.tracks(missingIds) : [];
      const fetchedById = new Map(fetched.filter((item) => item.id != null).map((item) => [String(item.id), item]));
      const tracks = rawTracks
        .map((item) => item.track ?? (item.id == null ? undefined : fetchedById.get(String(item.id))))
        .filter((track): track is YandexTrackLike & { id: string | number; title: string } => track !== undefined && isPlayableTrack(track))
        .map(mapTrack);
      const externalId = reference.uuid || `${reference.owner}:${reference.kind}`;
      const cover = playlist.coverUri || playlist.image;
      return {
        provider: "yandex",
        externalId,
        title: playlist.title?.trim() || "Плейлист Яндекс Музыки",
        artworkUrl: cover ? `https://${cover.replace(/^https?:\/\//, "").replace("%%", "1000x1000")}` : undefined,
        tracks
      };
    } catch (error) {
      if (error instanceof ProviderGatewayError) throw error;
      throw mapYandexError(error);
    }
  }

  private client(access?: ProviderAccess) {
    const token = access?.token?.trim() || this.defaultToken?.trim();
    if (!token) {
      throw new ProviderGatewayError(
        "PROVIDER_AUTH_REQUIRED",
        "A Yandex Music OAuth token is required",
        401
      );
    }
    if (token.length > 4096 || /[\r\n]/.test(token)) {
      throw new ProviderGatewayError(
        "INVALID_PROVIDER_TOKEN",
        "The Yandex Music token is invalid",
        401
      );
    }
    return this.clientFactory(token);
  }
}

function isPlayableTrack(track: YandexTrackLike): track is YandexTrackLike & {
  id: string | number;
  title: string;
} {
  return (
    track.available !== false &&
    track.id !== undefined &&
    typeof track.title === "string" &&
    track.title.length > 0
  );
}

function mapTrack(track: YandexTrackLike & { id: string | number; title: string }) {
  const id = String(track.id);
  const artist =
    track.artists
      ?.map((item) => item.name)
      .filter((name): name is string => Boolean(name))
      .join(", ") || "Unknown artist";
  const cover = track.coverUri?.replace("%%", "1000x1000");
  return {
    id,
    title: track.title,
    artist,
    album: track.albums?.[0]?.title,
    durationMs: track.durationMs,
    artworkUrl: cover ? `https://${cover.replace(/^https?:\/\//, "")}` : undefined,
    externalUrl: `https://music.yandex.ru/track/${encodeURIComponent(id)}`
  } satisfies ProviderTrack;
}

function selectVariant(
  variants: YandexDownloadInfoLike[],
  quality: AudioQuality
) {
  const target = { low: 128, medium: 192, high: 320, lossless: 320 }[quality];
  return [...variants].sort((left, right) => {
    const leftRate = left.bitrateInKbps ?? 0;
    const rightRate = right.bitrateInKbps ?? 0;
    const leftDistance = leftRate <= target ? target - leftRate : 10_000 + leftRate;
    const rightDistance = rightRate <= target ? target - rightRate : 10_000 + rightRate;
    return leftDistance - rightDistance;
  })[0];
}

function assertAllowedYandexStreamUrl(value: string) {
  const url = new URL(value);
  const allowed = [
    "yandex.net",
    "yandex.ru",
    "yandex.com",
    "yandex.kz",
    "yandexcloud.net"
  ];
  if (
    url.protocol !== "https:" ||
    !allowed.some(
      (domain) => url.hostname === domain || url.hostname.endsWith(`.${domain}`)
    )
  ) {
    throw new ProviderGatewayError(
      "UPSTREAM_ERROR",
      "Yandex Music returned an unexpected stream host",
      502
    );
  }
}

function mapYandexError(error: unknown) {
  const name = error instanceof Error ? error.name : "";
  if (name === "UnauthorizedError") {
    return new ProviderGatewayError(
      "INVALID_PROVIDER_TOKEN",
      "The Yandex Music token was rejected",
      401,
      { cause: error }
    );
  }
  if (name === "NotFoundError") {
    return new ProviderGatewayError(
      "TRACK_NOT_FOUND",
      "Yandex Music track was not found",
      404,
      { cause: error }
    );
  }
  if (name === "TimedOutError") {
    return new ProviderGatewayError(
      "UPSTREAM_TIMEOUT",
      "Yandex Music request timed out",
      502,
      { cause: error }
    );
  }
  return new ProviderGatewayError(
    "UPSTREAM_ERROR",
    "Yandex Music request failed",
    502,
    { cause: error }
  );
}
