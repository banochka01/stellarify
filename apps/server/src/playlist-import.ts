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
    private readonly vk?: VkAdapter,
    private readonly fetcher: typeof fetch = fetch
  ) {}

  async importUrl(value: string, access?: ProviderAccess, depth = 0): Promise<ImportedPlaylist> {
    let url: URL;
    try { url = new URL(value); } catch { throw new ProviderGatewayError("TRACK_NOT_FOUND", "Invalid playlist URL", 400); }
    const host = url.hostname.toLowerCase();
    if (isDotifyHost(host)) {
      if (depth > 0) throw new ProviderGatewayError("TRACK_NOT_FOUND", "Ссылка Dotify ведёт на другую ссылку Dotify", 400);
      return this.importUrl(await resolveDotifyShareUrl(url, this.fetcher), access, depth + 1);
    }
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

function isDotifyHost(host: string): boolean {
  return host === "dotify.fun" || host.endsWith(".dotify.fun");
}

/** Extracts the original provider URL that a Dotify share page wraps in its `dotify://…/<base64>` deep link. */
export function decodeDotifyDeepLink(html: string): string | undefined {
  for (const match of html.matchAll(/dotify:\/\/[^"'\s<>]+/g)) {
    const parts = match[0].slice("dotify://".length).split("/");
    // The base64 payload may itself contain "/", so try every path suffix.
    for (let start = 0; start < parts.length; start++) {
      const payload = parts.slice(start).join("/");
      try {
        const target = new URL(Buffer.from(payload.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8"));
        if ((target.protocol === "https:" || target.protocol === "http:") && !isDotifyHost(target.hostname)) return target.toString();
      } catch { /* try next candidate */ }
    }
  }
  return undefined;
}

async function resolveDotifyShareUrl(url: URL, fetcher: typeof fetch): Promise<string> {
  let html: string;
  try {
    const response = await fetcher(url.toString(), { redirect: "follow", signal: AbortSignal.timeout(10_000) });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    html = (await response.text()).slice(0, 512_000);
  } catch {
    throw new ProviderGatewayError("UPSTREAM_ERROR", "Не удалось открыть ссылку Dotify", 502);
  }
  const target = decodeDotifyDeepLink(html);
  if (!target) {
    throw new ProviderGatewayError("TRACK_NOT_FOUND", "В ссылке Dotify не найден плейлист", 400);
  }
  return target;
}
