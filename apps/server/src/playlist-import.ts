import {
  ProviderGatewayError,
  type ImportedProviderLibrary,
  type ProviderAccess,
  type ProviderName
} from "./provider-gateway.js";
import { SpotifyAdapter } from "./spotify.js";
import { VkAdapter, parseVkPlaylistReference } from "./vk.js";
import { YandexAdapter } from "./yandex.js";
import { YouTubeAdapter, type ImportedPlaylist } from "./youtube.js";

export class PlaylistImportService {
  constructor(
    private readonly yandex: YandexAdapter,
    private readonly youtube: YouTubeAdapter,
    private readonly spotify?: SpotifyAdapter,
    private readonly vk?: VkAdapter
  ) {}

  async importUrl(value: string, access?: ProviderAccess): Promise<ImportedPlaylist> {
    let url: URL;
    try { url = new URL(value); } catch { throw new ProviderGatewayError("TRACK_NOT_FOUND", "Invalid playlist URL", 400); }
    const host = url.hostname.toLowerCase();
    if (host === "music.youtube.com" || host === "youtube.com" || host === "www.youtube.com") {
      const id = url.searchParams.get("list");
      if (!id) throw new ProviderGatewayError("TRACK_NOT_FOUND", "YouTube playlist URL must include list", 400);
      return this.youtube.importPlaylist(id, access);
    }
    if (host === "music.yandex.ru" || host.endsWith(".music.yandex.ru") || host === "music.yandex.com") {
      const parts = url.pathname.split("/").filter(Boolean);
      const users = parts.indexOf("users");
      const playlists = parts.indexOf("playlists");
      if (users >= 0 && playlists > users && parts[users + 1] && parts[playlists + 1]) {
        return this.yandex.importPlaylist({ owner: parts[users + 1], kind: parts[playlists + 1] }, access);
      }
      const uuidIndex = parts.findIndex((part) => part === "playlist" || part === "playlists");
      if (uuidIndex >= 0 && parts[uuidIndex + 1]) return this.yandex.importPlaylist({ uuid: parts[uuidIndex + 1] }, access);
      const uuid = url.searchParams.get("uuid") || url.searchParams.get("playlistUuid");
      if (uuid) return this.yandex.importPlaylist({ uuid }, access);
      throw new ProviderGatewayError(
        "TRACK_NOT_FOUND",
        "Не удалось распознать ссылку Яндекс Музыки. Откройте плейлист и скопируйте ссылку через «Поделиться».",
        400
      );
    }
    if (host === "open.spotify.com" || host === "play.spotify.com") {
      if (!this.spotify) {
        throw new ProviderGatewayError("PROVIDER_NOT_SUPPORTED", "Spotify playlist import is not configured", 400);
      }
      const parts = url.pathname.split("/").filter(Boolean);
      const playlistIndex = parts.indexOf("playlist");
      const playlistId = playlistIndex >= 0 ? parts[playlistIndex + 1] : undefined;
      if (!playlistId) {
        throw new ProviderGatewayError("TRACK_NOT_FOUND", "Spotify playlist URL must include a playlist id", 400);
      }
      return this.spotify.importPlaylist(playlistId, access);
    }
    if (host === "vk.com" || host.endsWith(".vk.com") || host === "vk.ru" || host.endsWith(".vk.ru") || host === "m.vk.com") {
      if (!this.vk) {
        throw new ProviderGatewayError("PROVIDER_NOT_SUPPORTED", "VK Music import is not configured", 400);
      }
      const reference = parseVkPlaylistReference(url.pathname);
      if (!reference) {
        throw new ProviderGatewayError("TRACK_NOT_FOUND", "VK playlist URL is not recognized", 400);
      }
      return this.vk.importPlaylist(reference, access);
    }
    throw new ProviderGatewayError("PROVIDER_NOT_SUPPORTED", "This playlist provider is not supported", 400);
  }

  async importLibrary(provider: ProviderName, access?: ProviderAccess): Promise<ImportedProviderLibrary> {
    if (!access?.token?.trim()) {
      throw new ProviderGatewayError(
        "PROVIDER_AUTH_REQUIRED",
        "Для переноса медиатеки нужен токен выбранного сервиса",
        401
      );
    }
    if (provider === "yandex") return capImportedLibrary(await this.yandex.importLibrary(access));
    if (provider === "spotify" && this.spotify) {
      return capImportedLibrary(await this.spotify.importLibrary(access));
    }
    if (provider === "vk" && this.vk) return capImportedLibrary(await this.vk.importLibrary(access));
    throw new ProviderGatewayError(
      "PROVIDER_NOT_SUPPORTED",
      "Перенос всей медиатеки для этого сервиса пока недоступен",
      400
    );
  }
}

const MAX_IMPORTED_PLAYLIST_TRACKS = 8_000;

function capImportedLibrary(library: ImportedProviderLibrary): ImportedProviderLibrary {
  let remaining = MAX_IMPORTED_PLAYLIST_TRACKS;
  let truncated = library.truncated;
  const playlists = library.playlists.map((playlist) => {
    const tracks = playlist.tracks.slice(0, remaining);
    if (tracks.length < playlist.tracks.length) truncated = true;
    remaining -= tracks.length;
    return { ...playlist, tracks };
  });
  return { ...library, playlists, truncated };
}
