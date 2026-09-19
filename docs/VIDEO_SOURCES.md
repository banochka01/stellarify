# Fullscreen video sources

The Flutter Visual Stage requests `GET /api/v1/clips?title=...&artist=...`.
The API returns `{ "clips": [...] }`, ordered with matching music videos first.
Audio keeps playing through the existing audio service. Background players are
muted, disposed on leaving the stage, and paused with the music. Music videos
follow audio position (within 1.5 seconds); ambient footage loops independently.
Music videos freeze at their end rather than looping out of sync. Short preview
clips loop independently, like the visual snippets in music streaming apps.

## Available sources

1. **Apple Music video previews** — enabled by default and key-free. Resonance
   searches the configured storefronts (`CLIP_APPLE_COUNTRIES`, default
   `ru,us,gb,de,fr,jp`) concurrently and plays up to six matching official
   30-second promotional video previews. The
   source label opens the matching Apple Music page. Set
   `CLIP_APPLE_ENABLED=false` to disable this source.
2. **Яндекс Музыка** — when the current track has a Yandex source and the user
   or server has a valid token, Resonance requests the track's video supplement.
   Direct HTTPS media is playable; hosted watch pages are shown as external
   references. Credentials are request-scoped and results are marked private.
3. **YouTube** — with `YOUTUBE_API_KEY`, searches only music-category videos
   that YouTube reports as embeddable and syndicated. Official watch pages are
   listed in the source picker and opened in the official player; Resonance does
   not extract or proxy YouTube streams.
4. **Dailymotion** — enabled by default and key-free. Public music search results
   are shown as external references. Set `CLIP_DAILYMOTION_ENABLED=false` to
   disable them.
5. **Vimeo** — configure `VIMEO_ACCESS_TOKEN` to add public Vimeo search results
   as external references.
6. **MusicBrainz** — enabled by default and key-free. Resonance follows only
   recording relations explicitly marked as video and only to allow-listed
   YouTube, Vimeo and Dailymotion HTTPS pages. Set
   `CLIP_MUSICBRAINZ_ENABLED=false` to disable it.
7. **TheAudioDB** — configure `AUDIODB_API_KEY` to add curated music-video
   references. Only supported HTTPS video hosts are accepted.
8. **Server catalog** — exact normalized title/artist matching. Configure
   `CLIP_CATALOG_PATH` to a JSON file. Use `/data/clips.json` in the existing
   Docker data volume, then restart the API after editing it.
9. **Compatible APIs** — comma-separated `CLIP_PROVIDER_URLS`, up to twelve HTTPS
   endpoints. Each receives `title` and `artist` query parameters and returns
   the same catalog format. Redirects are disabled; timeout is six seconds;
   responses are limited to 1 MiB. These endpoints are administrator-controlled.
10. **Pexels** — optional `PEXELS_API_KEY`, with atmospheric landscape MP4 videos
   up to 1080p. These are explicitly labeled as backgrounds, not the song's
   music video. Creator attribution links to the original Pexels page.

Example catalog (replace the example URLs with your actual hosted files):

```json
{
  "clips": [
    {
      "id": "artist-signal",
      "title": "Signal",
      "artist": "Artist",
      "url": "https://media.example.com/signal.mp4",
      "playback": "direct",
      "kind": "musicVideo",
      "source": "Artist official",
      "sourceUrl": "https://artist.example.com/signal",
      "offsetMs": 0
    }
  ]
}
```

`kind` is `musicVideo`, `preview` or `ambient`. `playback` is `direct` or
`external`; external references omit `url` and must provide `sourceUrl`.
Ambient entries apply to any track.
`offsetMs` is video position minus audio position (useful for video intros).
Sources must provide direct HTTPS media URLs accessible by the client; HTML
watch pages and server credentials are not playable media. Media endpoints
should support byte ranges. Use stable URLs or signed URLs valid for at least
the 30-minute result cache plus a full listening session. Clients retry other
returned sources on playback error; source selection and retry are available
from the stage's Video sources button. Disabling video releases its player.

## Behavior and limits

Results are cached for 30 minutes (up to 500 track queries); concurrent
identical requests share one fetch. Pexels backgrounds share an hour cache.
At most 32 distinct queries can resolve concurrently. An unavailable remote
source does not prevent working catalog sources from being returned.
With every source disabled or no results, the artwork remains visible. With
only failing configured providers and no fallback, the API returns 502 and the
client offers retry. Keys and upstream errors are never returned to clients.

There is no built-in generic video fallback: when no track-specific clip or
configured Pexels background is available, clients explicitly show «Нет клипа».
Apple previews and direct catalog media are the sources that play inside the
stage. YouTube, Dailymotion, Vimeo and non-direct Yandex results remain official
external-player links: watch URLs are never extracted into native media streams.

## Checks

`npm run check -w @stellarify/server` and `npm test` cover catalog matching,
validation, source fallback, request coalescing, caching and API contracts.
Flutter stage tests cover unavailable sources, layouts and source controls.
Playback on physical Windows/Android/iOS devices should be checked with real
media before a release; widget tests do not exercise native video decoders.
