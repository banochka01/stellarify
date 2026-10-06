import { Router } from "express";
import { z } from "zod";

/**
 * Artist profiles for the client's artist page. Metadata comes from key-free
 * public catalogs (Deezer first, iTunes Search as a fallback); playback still
 * happens through the user's connected providers, so this service never
 * returns audio streams.
 */

const httpsUrl = z.string().url().max(2048).refine((value) => new URL(value).protocol === "https:");
const optionalUrl = httpsUrl.optional().catch(undefined);

export type ArtistTrack = {
  id: string;
  title: string;
  artist: string;
  album?: string;
  artworkUrl?: string;
  durationMs?: number;
};
export type ArtistAlbum = {
  id: string;
  title: string;
  artworkUrl?: string;
  releaseDate?: string;
  type: "album" | "single" | "ep" | "compilation";
};
export type ArtistSummary = {
  id: string;
  name: string;
  pictureUrl?: string;
  fans?: number;
};
export type ArtistProfile = {
  artist: ArtistSummary & { albumCount?: number; link?: string; source: "deezer" | "itunes" };
  topTracks: ArtistTrack[];
  albums: ArtistAlbum[];
  related: ArtistSummary[];
};
export type ArtistAlbumDetails = { album: ArtistAlbum & { artist: string }; tracks: ArtistTrack[] };

export class ArtistError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message);
  }
}

const deezerArtist = z.object({
  id: z.number(),
  name: z.string(),
  picture_xl: optionalUrl,
  picture_big: optionalUrl,
  nb_album: z.number().optional(),
  nb_fan: z.number().optional(),
  link: optionalUrl
});
const deezerTrack = z.object({
  id: z.number(),
  title: z.string(),
  duration: z.number().optional(),
  artist: z.object({ name: z.string() }).optional(),
  album: z.object({ title: z.string().optional(), cover_xl: optionalUrl, cover_big: optionalUrl }).optional()
});
const deezerAlbum = z.object({
  id: z.number(),
  title: z.string(),
  cover_xl: optionalUrl,
  cover_big: optionalUrl,
  release_date: z.string().optional(),
  record_type: z.string().optional()
});
const deezerList = <T extends z.ZodTypeAny>(item: T) => z.object({ data: z.array(z.unknown()) })
  .transform((value) => value.data.flatMap((entry) => {
    const parsed = item.safeParse(entry);
    return parsed.success ? [parsed.data as z.infer<T>] : [];
  }));

const itunesArtist = z.object({ wrapperType: z.literal("artist"), artistId: z.number(), artistName: z.string(), artistLinkUrl: optionalUrl });
const itunesAlbum = z.object({
  wrapperType: z.literal("collection"),
  collectionId: z.number(),
  collectionName: z.string(),
  artistName: z.string().optional(),
  artworkUrl100: optionalUrl,
  releaseDate: z.string().optional(),
  trackCount: z.number().optional()
});
const itunesSong = z.object({
  wrapperType: z.literal("track"),
  kind: z.literal("song").optional(),
  trackId: z.number(),
  trackName: z.string(),
  artistName: z.string(),
  collectionName: z.string().optional(),
  artworkUrl100: optionalUrl,
  trackTimeMillis: z.number().optional(),
  trackNumber: z.number().optional()
});
const itunesList = z.object({ results: z.array(z.unknown()) });

export const normalizeArtistName = (value: string) => value.normalize("NFKC").toLocaleLowerCase()
  .replace(/^the\s+/u, "")
  .replace(/[^\p{L}\p{N}]+/gu, "");

const albumType = (value?: string, trackCount?: number): ArtistAlbum["type"] => {
  if (value === "single") return trackCount && trackCount > 3 ? "ep" : "single";
  if (value === "ep") return "ep";
  if (value === "compile") return "compilation";
  return "album";
};

export class ArtistService {
  private readonly cache = new Map<string, { expires: number; value: unknown }>();
  private readonly pending = new Map<string, Promise<unknown>>();

  constructor(
    private readonly request: typeof fetch = fetch,
    private readonly options: { ttlMs?: number; itunesCountry?: string } = {}
  ) {}

  profile(name: string): Promise<ArtistProfile> {
    const key = `profile:${normalizeArtistName(name)}`;
    if (!normalizeArtistName(name)) {
      return Promise.reject(new ArtistError(400, "INVALID_REQUEST", "Artist name is empty"));
    }
    return this.cached(key, () => this.loadProfile(name.trim()));
  }

  album(id: string): Promise<ArtistAlbumDetails> {
    const match = /^(deezer|itunes):(\d{1,20})$/.exec(id);
    if (!match) return Promise.reject(new ArtistError(400, "INVALID_REQUEST", "Unknown album id"));
    return this.cached(`album:${id}`, () => match[1] === "deezer"
      ? this.deezerAlbum(match[2]!)
      : this.itunesAlbum(match[2]!));
  }

  private async cached<T>(key: string, load: () => Promise<T>): Promise<T> {
    const hit = this.cache.get(key);
    if (hit && hit.expires > Date.now()) return hit.value as T;
    const running = this.pending.get(key);
    if (running) return running as Promise<T>;
    const promise = load().then((value) => {
      this.cache.set(key, { expires: Date.now() + (this.options.ttlMs ?? 6 * 60 * 60 * 1000), value });
      if (this.cache.size > 500) this.cache.delete(this.cache.keys().next().value!);
      return value;
    }).finally(() => this.pending.delete(key));
    this.pending.set(key, promise);
    return promise;
  }

  private async loadProfile(name: string): Promise<ArtistProfile> {
    let deezerFailure: unknown;
    try {
      const profile = await this.deezerProfile(name);
      if (profile) return profile;
    } catch (error) {
      deezerFailure = error;
    }
    let itunesFailure: unknown;
    try {
      const profile = await this.itunesProfile(name);
      if (profile) return profile;
    } catch (error) {
      itunesFailure = error;
    }
    if (deezerFailure && itunesFailure) {
      throw new ArtistError(502, "ARTIST_SOURCES_UNAVAILABLE", "Artist catalogs are unavailable");
    }
    throw new ArtistError(404, "ARTIST_NOT_FOUND", "Artist not found");
  }

  private async deezerProfile(name: string): Promise<ArtistProfile | null> {
    const search = new URL("https://api.deezer.com/search/artist");
    search.search = new URLSearchParams({ q: name, limit: "8" }).toString();
    const candidates = deezerList(deezerArtist).parse(await this.json(search));
    const artist = pickArtist(candidates, (item) => item.name, (item) => item.nb_fan ?? 0, name);
    if (!artist) return null;
    const base = `https://api.deezer.com/artist/${artist.id}`;
    const [top, albums, related] = await Promise.allSettled([
      this.json(new URL(`${base}/top?limit=15`)).then((data) => deezerList(deezerTrack).parse(data)),
      this.json(new URL(`${base}/albums?limit=40`)).then((data) => deezerList(deezerAlbum).parse(data)),
      this.json(new URL(`${base}/related?limit=12`)).then((data) => deezerList(deezerArtist).parse(data))
    ]);
    return {
      artist: {
        id: `deezer:${artist.id}`,
        name: artist.name,
        pictureUrl: artist.picture_xl ?? artist.picture_big,
        fans: artist.nb_fan,
        albumCount: artist.nb_album,
        link: artist.link,
        source: "deezer"
      },
      topTracks: top.status === "fulfilled" ? top.value.map((track) => ({
        id: `deezer:${track.id}`,
        title: track.title,
        artist: track.artist?.name ?? artist.name,
        album: track.album?.title,
        artworkUrl: track.album?.cover_xl ?? track.album?.cover_big,
        durationMs: track.duration ? track.duration * 1000 : undefined
      })) : [],
      albums: albums.status === "fulfilled" ? dedupeAlbums(albums.value.map((album) => ({
        id: `deezer:${album.id}`,
        title: album.title,
        artworkUrl: album.cover_xl ?? album.cover_big,
        releaseDate: album.release_date,
        type: albumType(album.record_type)
      }))) : [],
      related: related.status === "fulfilled" ? related.value.slice(0, 12).map((item) => ({
        id: `deezer:${item.id}`,
        name: item.name,
        pictureUrl: item.picture_xl ?? item.picture_big,
        fans: item.nb_fan
      })) : []
    };
  }

  private async deezerAlbum(id: string): Promise<ArtistAlbumDetails> {
    const data = z.object({
      id: z.number(),
      title: z.string(),
      cover_xl: optionalUrl,
      cover_big: optionalUrl,
      release_date: z.string().optional(),
      record_type: z.string().optional(),
      artist: z.object({ name: z.string() }),
      tracks: z.object({ data: z.array(z.unknown()) })
    }).parse(await this.json(new URL(`https://api.deezer.com/album/${id}`)));
    const artwork = data.cover_xl ?? data.cover_big;
    return {
      album: {
        id: `deezer:${data.id}`,
        title: data.title,
        artist: data.artist.name,
        artworkUrl: artwork,
        releaseDate: data.release_date,
        type: albumType(data.record_type)
      },
      tracks: deezerList(deezerTrack).parse(data.tracks).map((track) => ({
        id: `deezer:${track.id}`,
        title: track.title,
        artist: track.artist?.name ?? data.artist.name,
        album: data.title,
        artworkUrl: artwork,
        durationMs: track.duration ? track.duration * 1000 : undefined
      }))
    };
  }

  private async itunesProfile(name: string): Promise<ArtistProfile | null> {
    const search = this.itunesUrl("search", { term: name, entity: "musicArtist", limit: "8" });
    const candidates = itunesList.parse(await this.json(search)).results
      .flatMap((entry) => {
        const parsed = itunesArtist.safeParse(entry);
        return parsed.success ? [parsed.data] : [];
      });
    const artist = pickArtist(candidates, (item) => item.artistName, () => 0, name);
    if (!artist) return null;
    const [songs, albums] = await Promise.all([
      this.json(this.itunesUrl("lookup", { id: String(artist.artistId), entity: "song", limit: "15" })),
      this.json(this.itunesUrl("lookup", { id: String(artist.artistId), entity: "album", limit: "40" }))
    ]);
    const tracks = itunesList.parse(songs).results.flatMap((entry) => {
      const parsed = itunesSong.safeParse(entry);
      return parsed.success ? [parsed.data] : [];
    });
    const collections = itunesList.parse(albums).results.flatMap((entry) => {
      const parsed = itunesAlbum.safeParse(entry);
      return parsed.success ? [parsed.data] : [];
    });
    const mappedAlbums = dedupeAlbums(collections
      .sort((left, right) => (right.releaseDate ?? "").localeCompare(left.releaseDate ?? ""))
      .map((album) => ({
        id: `itunes:${album.collectionId}`,
        title: album.collectionName.replace(/\s+-\s+(Single|EP)$/u, ""),
        artworkUrl: largeItunesArtwork(album.artworkUrl100),
        releaseDate: album.releaseDate?.slice(0, 10),
        type: /\s-\sSingle$/u.test(album.collectionName)
          ? "single" as const
          : /\s-\sEP$/u.test(album.collectionName) ? "ep" as const : albumType(undefined, album.trackCount)
      })));
    return {
      artist: {
        id: `itunes:${artist.artistId}`,
        name: artist.artistName,
        pictureUrl: mappedAlbums[0]?.artworkUrl,
        albumCount: mappedAlbums.length,
        link: artist.artistLinkUrl,
        source: "itunes"
      },
      topTracks: tracks.map((track) => ({
        id: `itunes:${track.trackId}`,
        title: track.trackName,
        artist: track.artistName,
        album: track.collectionName,
        artworkUrl: largeItunesArtwork(track.artworkUrl100),
        durationMs: track.trackTimeMillis
      })),
      albums: mappedAlbums,
      related: []
    };
  }

  private async itunesAlbum(id: string): Promise<ArtistAlbumDetails> {
    const results = itunesList.parse(await this.json(this.itunesUrl("lookup", { id, entity: "song", limit: "100" }))).results;
    const album = results.map((entry) => itunesAlbum.safeParse(entry)).find((parsed) => parsed.success)?.data;
    if (!album) throw new ArtistError(404, "ALBUM_NOT_FOUND", "Album not found");
    const artwork = largeItunesArtwork(album.artworkUrl100);
    const title = album.collectionName.replace(/\s+-\s+(Single|EP)$/u, "");
    return {
      album: {
        id: `itunes:${album.collectionId}`,
        title,
        artist: album.artistName ?? "",
        artworkUrl: artwork,
        releaseDate: album.releaseDate?.slice(0, 10),
        type: albumType(undefined, album.trackCount)
      },
      tracks: results.flatMap((entry) => {
        const parsed = itunesSong.safeParse(entry);
        return parsed.success ? [parsed.data] : [];
      }).sort((left, right) => (left.trackNumber ?? 0) - (right.trackNumber ?? 0)).map((track) => ({
        id: `itunes:${track.trackId}`,
        title: track.trackName,
        artist: track.artistName,
        album: title,
        artworkUrl: artwork,
        durationMs: track.trackTimeMillis
      }))
    };
  }

  private itunesUrl(path: "search" | "lookup", params: Record<string, string>) {
    const url = new URL(`https://itunes.apple.com/${path}`);
    url.search = new URLSearchParams({ ...params, country: this.options.itunesCountry ?? "ru" }).toString();
    return url;
  }

  private async json(url: URL): Promise<unknown> {
    const response = await this.request(url, {
      headers: { accept: "application/json" },
      signal: AbortSignal.timeout(8000)
    });
    if (!response.ok) throw new Error(`Artist source responded with ${response.status}`);
    const body = await response.json() as unknown;
    if (body && typeof body === "object" && "error" in body) throw new Error("Artist source error");
    return body;
  }
}

function pickArtist<T>(items: T[], name: (item: T) => string, popularity: (item: T) => number, query: string): T | undefined {
  const wanted = normalizeArtistName(query);
  const exact = items.filter((item) => normalizeArtistName(name(item)) === wanted);
  if (exact.length) return exact.sort((left, right) => popularity(right) - popularity(left))[0];
  const close = items.filter((item) => {
    const candidate = normalizeArtistName(name(item));
    return candidate.length > 0 && (candidate.includes(wanted) || wanted.includes(candidate));
  });
  return close.sort((left, right) => popularity(right) - popularity(left))[0];
}

function dedupeAlbums(albums: ArtistAlbum[]): ArtistAlbum[] {
  const seen = new Set<string>();
  return albums.filter((album) => {
    const key = `${album.title.normalize("NFKC").toLocaleLowerCase().replace(/\s*\((deluxe|explicit|clean)[^)]*\)/giu, "")}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).slice(0, 40);
}

function largeItunesArtwork(url?: string) {
  return url?.replace(/\/\d+x\d+(bb)?\.(jpg|png)$/u, "/600x600bb.$2");
}

const profileQuery = z.object({ name: z.string().trim().min(1).max(200) });
const albumParams = z.object({ id: z.string().regex(/^(deezer|itunes):\d{1,20}$/) });

export function createArtistRouter(service: ArtistService) {
  const router = Router();
  router.get("/", async (request, response) => {
    const input = profileQuery.safeParse(request.query);
    if (!input.success) {
      response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid artist request" } });
      return;
    }
    try {
      response.setHeader("cache-control", "public, max-age=1800, stale-while-revalidate=21600");
      response.json(await service.profile(input.data.name));
    } catch (error) {
      sendArtistError(response, error);
    }
  });
  router.get("/albums/:id", async (request, response) => {
    const input = albumParams.safeParse(request.params);
    if (!input.success) {
      response.status(400).json({ error: { code: "INVALID_REQUEST", message: "Invalid album request" } });
      return;
    }
    try {
      response.setHeader("cache-control", "public, max-age=3600, stale-while-revalidate=86400");
      response.json(await service.album(input.data.id));
    } catch (error) {
      sendArtistError(response, error);
    }
  });
  return router;
}

function sendArtistError(response: import("express").Response, error: unknown) {
  response.removeHeader("cache-control");
  if (error instanceof ArtistError) {
    response.status(error.status).json({ error: { code: error.code, message: error.status === 404 ? "Артист не найден" : "Каталог артистов недоступен" } });
    return;
  }
  response.status(502).json({ error: { code: "ARTIST_SOURCES_UNAVAILABLE", message: "Каталог артистов недоступен" } });
}
