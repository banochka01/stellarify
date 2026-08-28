# Stellarify architecture

## Product boundary

Stellarify stores a normalized library of references and metadata. Audio is
played by an official provider SDK, embed, or an explicitly authorized stream
URL. The backend does not download, decrypt, or cache third-party music. The
only relay path is the user-enabled SoundCloud progressive-audio proxy described
below; it streams bytes without writing them to storage.

This is important because the providers expose very different capabilities:

| Provider | Import | Playback in Stellarify | MVP approach |
| --- | --- | --- | --- |
| Spotify | OAuth + Web API | Web Playback SDK, Premium account | Adapter + official SDK |
| SoundCloud | Public API v2 Client ID or API OAuth token | Short-lived attributed HLS/MP3 URL | Server adapter + native player |
| YouTube / YouTube Music | Data API | YouTube IFrame Player | Adapter + official embed |
| Yandex Music | User OAuth token | Short-lived account-bound stream URL | Token adapter |
| VK Music | Link import only | Open in official client | Metadata/link adapter |

Provider application credentials belong on the backend. Resonance native
clients keep manually supplied per-user access tokens in platform secure
storage and send them only to the gateway over HTTPS for the selected request.

## Provider playback gateway

The versioned gateway exposes provider-neutral operations:

- `GET /api/v1/catalog/search` normalizes provider search results.
- `POST /api/v1/playback/resolve` resolves a provider track ID to an expiring
  stream descriptor.
- `GET /api/v1/playback/providers` reports configured adapters.

The SoundCloud adapter accepts either an API OAuth token or a Client ID from
the `X-Provider-Token` header and otherwise uses the server-side Client ID. A
browser `oauth_token` cookie is not an API credential and is ignored during
normal search/playback so an old value cannot shadow the configured server
credential. Unknown or encrypted transcoding protocols are ignored. Native
clients prefer progressive MP3 because SoundCloud's fragmented-MP4 HLS is not
decoded reliably by the bundled Windows and Android playback engine; MPEG HLS
and other HLS streams remain fallbacks. Resolved URLs stay in a small,
short-lived, credential-scoped memory cache. When the user enables the
SoundCloud server proxy, public Client ID playback is forced to progressive MP3
and streamed through a
short-lived opaque relay ticket. The relay accepts only server-resolved
SoundCloud CDN URLs, forwards byte ranges, keeps proxy credentials server-side,
and never stores audio bytes. With the toggle off, the provider URL is returned
directly to the native player.

The Yandex adapter receives an individual OAuth token in the
`X-Provider-Token` header, uses it only for the current upstream request, and
never writes it to application storage or logs. Resolved URL cache entries are
partitioned by a one-way token digest so a stream resolved for one account is
never served from cache to another account. This adapter targets Yandex Music's
non-public client API and therefore needs contract monitoring.

## Repository

```text
apps/
  server/       Express API, import parser, Socket.IO room coordinator
  web/          React PWA and shared Tauri UI
    src-tauri/  Windows/Android/iOS application shell
docs/
```

## Rooms

Room state is provider-neutral:

```text
track reference + paused/playing + position + monotonic version + updated time
```

The host publishes state changes. Each participant uses their own authorized
provider player and corrects clock drift locally. No audio is broadcast by the
room server.

The MVP keeps rooms in memory. Production should move presence to Redis and
durable room/queue data to PostgreSQL. Playback commands must then be signed,
rate-limited, and accepted only from the current host.

## Network access

A future network profile may proxy Stellarify's own API calls for reliability
and privacy. It must not bypass provider geo restrictions, hide the user's
region, or proxy protected audio streams. Provider access remains subject to
the user's account, location, and the provider's terms.

## Next production milestones

1. Authentication, PostgreSQL schema, encrypted OAuth token vault.
2. Spotify OAuth/PKCE and playlist import.
3. YouTube Data API search and visible IFrame/WebView playback. YouTube never
   enters the native audio-only resolver or background-audio path.
4. SoundCloud OAuth/PKCE and widget playback.
5. Redis-backed room presence and host authorization.
6. Background audio/session controls in native shells.
7. Observability, abuse controls, privacy policy, and provider review.
