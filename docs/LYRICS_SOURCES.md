# Lyrics sources

`GET /api/v1/lyrics` resolves lyrics in a fault-tolerant cascade. A failed
provider never prevents another provider from answering.

## Built-in providers

1. **LRCLIB** — key-free primary source for synchronized LRC and plain text.
   Exact track metadata and duration are sent first; a ranked search is used
   when the exact endpoint returns no match.
2. **Яндекс Музыка** — request-scoped synchronized LRC or plain text for tracks
   that already have a Yandex source. The client sends that source id and the
   user's token only for this request. Responses are private and are never put
   in the shared server cache.
3. **Musixmatch** — optional licensed source configured with
   `MUSIXMATCH_API_KEY`. Resonance requests `matcher.subtitle.get` in LRC format
   first, then falls back to `matcher.lyrics.get` when no synchronized subtitle
   is available. Restricted responses are not displayed.
4. **Lyrics.ovh** — key-free plain-text fallback.

## Compatible providers

`LYRICS_FALLBACK_URLS` accepts up to twelve comma-separated HTTPS endpoints.
Each receives `title`, `artist`, optional `album`, and optional `durationMs`.
It may return Resonance JSON with `lines`, `syncedLyrics`, `plainLyrics`, or a
minimal `{ "lyrics": "..." }` response. This hook is intended for licensed
LyricFind, private catalogs, self-hosted sources, and future providers without
requiring another client release.

The server prefers synchronized candidates, caps upstream responses at 512 KiB,
uses six-second timeouts, limits documents to 2,500 lines, and caches public
positive results for six hours. It does not scrape lyrics websites or use
private Spotify/Apple endpoints.
