# Fullscreen video sources

The Flutter Visual Stage requests `GET /api/v1/clips?title=...&artist=...`.
The API returns `{ "clips": [...] }`, ordered with matching music videos first.
Audio keeps playing through the existing audio service. Background players are
muted, disposed on leaving the stage, and paused with the music. Music videos
follow audio position (within 1.5 seconds); ambient footage loops independently.
Music videos freeze at their end rather than looping out of sync.

## Available sources

1. **Server catalog** — exact normalized title/artist matching. Configure
   `CLIP_CATALOG_PATH` to a JSON file. Use `/data/clips.json` in the existing
   Docker data volume, then restart the API after editing it.
2. **Compatible APIs** — comma-separated `CLIP_PROVIDER_URLS`, up to four HTTPS
   endpoints. Each receives `title` and `artist` query parameters and returns
   the same catalog format. Redirects are disabled; timeout is six seconds;
   responses are limited to 1 MiB. These endpoints are administrator-controlled.
3. **Pexels** — optional `PEXELS_API_KEY`, with atmospheric landscape MP4 videos
   up to 1080p. These are explicitly labeled as backgrounds, not the song's
   music video. Creator attribution links to the original Pexels page.
4. **Built-in NASA footage** — enabled by default, no credentials required.
   [Aurora Australis from the ISS](https://svs.gsfc.nasa.gov/31281/) by Earth
   Science and Remote Sensing Unit, NASA Johnson Space Center. The lightweight
   1080p WebM is preferred; MP4 is offered as a codec fallback. Public-domain
   provenance is also recorded on [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Aurora_Australis_as_seen_from_ISS_(SVS31281_-_1080p25).webm).
   Set `CLIP_BUILTIN_ENABLED=false` to disable it.

Example catalog (replace the example URLs with your actual hosted files):

```json
{
  "clips": [
    {
      "id": "artist-signal",
      "title": "Signal",
      "artist": "Artist",
      "url": "https://media.example.com/signal.mp4",
      "kind": "musicVideo",
      "source": "Artist official",
      "sourceUrl": "https://artist.example.com/signal",
      "offsetMs": 0
    }
  ]
}
```

`kind` is `musicVideo` or `ambient`. Ambient entries apply to any track.
`offsetMs` is video position minus audio position (useful for video intros).
Sources must provide direct HTTPS media URLs accessible by the client; HTML
watch pages and server credentials are not playable media. Media endpoints
should support byte ranges. Use stable URLs or signed URLs valid for at least
the five-minute result cache plus a full listening session. Clients retry other
returned sources on playback error; source selection and retry are available
from the stage's Video sources button. Disabling video releases its player.

## Behavior and limits

Results are cached for five minutes (up to 500 track queries); concurrent
identical requests share one fetch. Pexels backgrounds share an hour cache.
At most 32 distinct queries can resolve concurrently. An unavailable remote
source does not prevent working catalog/built-in sources from being returned.
With every source disabled or no results, the artwork remains visible. With
only failing configured providers and no fallback, the API returns 502 and the
client offers retry. Keys and upstream errors are never returned to clients.

The built-in source is ambient footage, not an official clip for every song.
Exact music videos require your catalog or a compatible provider. YouTube
watch URLs are not extracted into native media streams. Pexels integration
follows the [official API contract](https://www.pexels.com/api/documentation/).

## Checks

`npm run check -w @stellarify/server` and `npm test` cover catalog matching,
validation, source fallback, request coalescing, caching and API contracts.
Flutter stage tests cover unavailable sources, layouts and source controls.
Playback on physical Windows/Android/iOS devices should be checked with real
media before a release; widget tests do not exercise native video decoders.
