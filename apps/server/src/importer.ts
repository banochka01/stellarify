import type { ProviderId } from "./providers.js";

export type ImportedSource = {
  provider: ProviderId;
  kind: "playlist" | "track" | "profile" | "text";
  sourceUrl?: string;
  externalId?: string;
  label: string;
};

const cleanExternalId = (value: string | null | undefined) =>
  value?.replace(/[/?#].*$/, "") || undefined;

export function detectProvider(value: string): ProviderId {
  const input = value.toLowerCase();
  if (input.includes("open.spotify.com")) return "spotify";
  if (input.includes("soundcloud.com")) return "soundcloud";
  if (input.includes("youtube.com") || input.includes("youtu.be")) return "youtube";
  if (input.includes("music.yandex.")) return "yandex";
  if (input.includes("vk.com") || input.includes("vk.ru")) return "vk";
  return "unknown";
}

export function parseImportLine(rawLine: string): ImportedSource {
  const line = rawLine.trim();
  const provider = detectProvider(line);

  try {
    const url = new URL(line);
    const path = url.pathname.split("/").filter(Boolean);

    if (provider === "spotify") {
      const kind = path[0] === "playlist" ? "playlist" : "track";
      return {
        provider,
        kind,
        sourceUrl: url.toString(),
        externalId: cleanExternalId(path[1]),
        label: kind === "playlist" ? "Плейлист Spotify" : "Трек Spotify"
      };
    }

    if (provider === "youtube") {
      const listId = url.searchParams.get("list");
      const videoId =
        url.hostname === "youtu.be" ? path[0] : url.searchParams.get("v");
      return {
        provider,
        kind: listId ? "playlist" : "track",
        sourceUrl: url.toString(),
        externalId: cleanExternalId(listId || videoId),
        label: listId ? "Плейлист YouTube" : "Трек YouTube"
      };
    }

    if (provider === "soundcloud") {
      const isPlaylist = path.includes("sets");
      return {
        provider,
        kind: isPlaylist ? "playlist" : path.length > 1 ? "track" : "profile",
        sourceUrl: url.toString(),
        externalId: cleanExternalId(path.at(-1)),
        label: isPlaylist ? "Плейлист SoundCloud" : "Ссылка SoundCloud"
      };
    }

    if (provider === "yandex") {
      const playlistIndex = path.indexOf("playlists");
      return {
        provider,
        kind: playlistIndex >= 0 ? "playlist" : "track",
        sourceUrl: url.toString(),
        externalId: cleanExternalId(
          playlistIndex >= 0 ? path[playlistIndex + 1] : path.at(-1)
        ),
        label: playlistIndex >= 0 ? "Плейлист Яндекс Музыки" : "Ссылка Яндекс Музыки"
      };
    }

    if (provider === "vk") {
      const target = path.join("/");
      return {
        provider,
        kind: target.includes("playlist") ? "playlist" : "track",
        sourceUrl: url.toString(),
        externalId: cleanExternalId(path.at(-1)),
        label: target.includes("playlist") ? "Плейлист VK Музыки" : "Ссылка VK Музыки"
      };
    }
  } catch {
    // Non-URL text is accepted as a library note/search seed.
  }

  return {
    provider: "unknown",
    kind: "text",
    label: line
  };
}

export function parseImportPayload(value: string): ImportedSource[] {
  const uniqueLines = [
    ...new Set(
      value
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean)
    )
  ];

  return uniqueLines.slice(0, 100).map(parseImportLine);
}

