import express from "express";
import { z } from "zod";
import { clientKey, handle, parse, RateGate, TtlCache } from "./api-helpers.js";

export type Setlist = {
  id: string;
  eventDate: string;
  venue: string | null;
  city: string | null;
  country: string | null;
  tour: string | null;
  url: string | null;
  tracks: Array<{ title: string; query: string; cover: boolean; tape: boolean }>;
};

/**
 * Recent setlists via setlist.fm (optional: SETLISTFM_API_KEY). Without a key
 * the service reports `available: false` and returns nothing.
 */
export class SetlistService {
  readonly #cache: TtlCache<Setlist[]>;

  constructor(
    private readonly apiKey = "",
    private readonly request: typeof fetch = fetch,
    now: () => number = Date.now
  ) {
    this.#cache = new TtlCache(6 * 60 * 60_000, 500, now);
  }

  static fromEnvironment(env = process.env) {
    return new SetlistService(env.SETLISTFM_API_KEY?.trim() || "");
  }

  get available() {
    return Boolean(this.apiKey);
  }

  async recent(artist: string, limit = 5): Promise<{ available: boolean; setlists: Setlist[] }> {
    if (!this.available) return { available: false, setlists: [] };
    const name = artist.trim();
    const setlists = await this.#cache.get(name.toLowerCase(), () => this.#fetch(name));
    return { available: true, setlists: setlists.slice(0, limit) };
  }

  async #fetch(artist: string): Promise<Setlist[]> {
    const url = new URL("https://api.setlist.fm/rest/1.0/search/setlists");
    url.searchParams.set("artistName", artist);
    url.searchParams.set("p", "1");
    const response = await this.request(url, {
      headers: { accept: "application/json", "x-api-key": this.apiKey, "accept-language": "en" },
      signal: AbortSignal.timeout(8_000)
    }).catch(() => undefined);
    // 404 = no setlists for this artist; other failures degrade to an empty list.
    if (!response?.ok) return [];
    const data = await response.json().catch(() => ({})) as { setlist?: unknown[] };
    const wanted = artist.toLowerCase();
    return (Array.isArray(data.setlist) ? data.setlist : []).flatMap((raw) => {
      const item = raw as Record<string, any>;
      const artistName = String(item.artist?.name ?? "");
      if (artistName && artistName.toLowerCase() !== wanted && !artistName.toLowerCase().includes(wanted)) return [];
      const songs: Array<Record<string, any>> = (Array.isArray(item.sets?.set) ? item.sets.set : [])
        .flatMap((set: Record<string, any>) => (Array.isArray(set.song) ? set.song : []));
      const tracks = songs.filter((song) => typeof song.name === "string" && song.name.trim()).map((song) => {
        const performer = typeof song.cover?.name === "string" ? song.cover.name : artistName || artist;
        return {
          title: String(song.name).trim(),
          query: `${performer} ${String(song.name).trim()}`.slice(0, 200),
          cover: Boolean(song.cover),
          tape: song.tape === true
        };
      });
      if (!tracks.length || typeof item.id !== "string") return [];
      return [{
        id: item.id,
        eventDate: toIsoDate(String(item.eventDate ?? "")),
        venue: item.venue?.name ? String(item.venue.name) : null,
        city: item.venue?.city?.name ? String(item.venue.city.name) : null,
        country: item.venue?.city?.country?.name ? String(item.venue.city.country.name) : null,
        tour: item.tour?.name ? String(item.tour.name) : null,
        url: typeof item.url === "string" && item.url.startsWith("https://") ? item.url : null,
        tracks
      }];
    });
  }
}

/** setlist.fm uses dd-MM-yyyy. */
function toIsoDate(value: string) {
  const match = value.match(/^(\d{2})-(\d{2})-(\d{4})$/u);
  return match ? `${match[3]}-${match[2]}-${match[1]}` : value;
}

export function createSetlistRouter(service: SetlistService) {
  const router = express.Router();
  const gate = new RateGate(30, 60_000);
  router.get("/", handle(async (request, response) => {
    gate.check(clientKey(request));
    const query = parse(z.object({
      artist: z.string().trim().min(1).max(200),
      limit: z.coerce.number().int().min(1).max(20).default(5)
    }), request.query, "Укажите артиста");
    response.setHeader("cache-control", "public, max-age=3600");
    return service.recent(query.artist, query.limit);
  }));
  return router;
}
