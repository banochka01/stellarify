import { ProviderGatewayError, type ProviderAccess } from "./provider-gateway.js";
import { YandexAdapter } from "./yandex.js";
import { YouTubeAdapter, type ImportedPlaylist } from "./youtube.js";

export class PlaylistImportService {
  constructor(private readonly yandex: YandexAdapter, private readonly youtube: YouTubeAdapter) {}

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
      const uuidIndex = parts.indexOf("playlist");
      if (uuidIndex >= 0 && parts[uuidIndex + 1]) return this.yandex.importPlaylist({ uuid: parts[uuidIndex + 1] }, access);
      throw new ProviderGatewayError("TRACK_NOT_FOUND", "Yandex playlist URL is not recognized", 400);
    }
    if (host === "vk.com" || host.endsWith(".vk.com") || host === "vk.ru" || host.endsWith(".vk.ru")) {
      throw new ProviderGatewayError("PROVIDER_NOT_SUPPORTED", "VK Music does not provide a public playlist API for third-party import", 400);
    }
    throw new ProviderGatewayError("PROVIDER_NOT_SUPPORTED", "This playlist provider is not supported", 400);
  }
}
