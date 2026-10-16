import { z } from "zod";
import { ProviderGatewayError, type ProviderAccess, type ProviderTrack } from "./provider-gateway.js";
import type { SoundCloudAdapter } from "./soundcloud.js";

/** A `.dotifyplaylist` export: JSON with the full track list and each track's source service. */
export const dotifyFileSchema = z.object({
  id: z.string().max(200).optional(),
  title: z.string().max(500).optional(),
  tracks: z.array(z.object({
    id: z.union([z.string(), z.number()]).transform(String),
    title: z.string().max(500),
    artist: z.string().max(500).optional().default(""),
    album: z.union([z.string(), z.object({ title: z.string().optional() }).passthrough()]).optional(),
    duration: z.number().optional(),
    cover_art: z.string().max(2_048).optional(),
    source: z.string().max(40)
  }).passthrough()).max(8_000)
}).passthrough();

export type DotifyFile = z.infer<typeof dotifyFileSchema>;
export type DotifyImportedTrack = ProviderTrack & { provider: "soundcloud" | "yandex" | "youtube" };

export async function importDotifyFile(
  file: DotifyFile,
  soundcloud: Pick<SoundCloudAdapter, "searchTracks"> | undefined,
  access?: ProviderAccess
): Promise<{ externalId: string; title: string; tracks: DotifyImportedTrack[]; unmatched: number }> {
  const tracks: DotifyImportedTrack[] = [];
  let unmatched = 0;
  for (const entry of file.tracks) {
    const base = {
      title: entry.title,
      artist: entry.artist,
      album: typeof entry.album === "string" ? entry.album : entry.album?.title,
      durationMs: entry.duration ? Math.round(entry.duration * 1000) : undefined,
      artworkUrl: entry.cover_art?.startsWith("https://") ? entry.cover_art : undefined
    };
    const id = entry.id.trim();
    if (entry.source === "soundcloud" && /^\d+$/.test(id)) {
      tracks.push({ ...base, provider: "soundcloud", id: `soundcloud:tracks:${id}`, externalUrl: `https://api.soundcloud.com/tracks/${id}` });
    } else if (entry.source === "yandex" && /^\d+(:\d+)?$/.test(id)) {
      tracks.push({ ...base, provider: "yandex", id, externalUrl: `https://music.yandex.ru/track/${id.split(":")[0]}` });
    } else if (entry.source === "youtube" && /^[\w-]{6,20}$/.test(id)) {
      tracks.push({ ...base, provider: "youtube", id, externalUrl: `https://www.youtube.com/watch?v=${id}` });
    } else {
      // Apple Music and other sources Resonance cannot play: match by name on SoundCloud.
      const match = await searchSoundCloud(soundcloud, `${entry.artist} ${entry.title}`.trim(), access);
      if (match) tracks.push({ ...match, provider: "soundcloud" });
      else unmatched += 1;
    }
  }
  if (!tracks.length) {
    throw new ProviderGatewayError("TRACK_NOT_FOUND", "В файле Dotify нет треков, которые можно перенести", 400);
  }
  return {
    externalId: `dotify:${file.id ?? ""}`,
    title: file.title?.trim() || "Плейлист Dotify",
    tracks,
    unmatched
  };
}

async function searchSoundCloud(
  soundcloud: Pick<SoundCloudAdapter, "searchTracks"> | undefined,
  query: string,
  access?: ProviderAccess
): Promise<ProviderTrack | undefined> {
  if (!soundcloud || !query) return undefined;
  try {
    return (await soundcloud.searchTracks(query, 1, access))[0];
  } catch {
    return undefined;
  }
}
