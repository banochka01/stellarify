# Resonance architecture

## Scope

Stage 1 is an offline foundation. It proves that the application shell,
database, immutable domain model, provider contracts, queue, fallback policy,
secure storage boundary, and native media_kit player compile and are testable.
It does not call real provider endpoints.

## Dependency direction

```text
features + shared UI
        |
        v
Riverpod providers + application services
        |
        v
domain entities / repositories / provider contracts
        ^
        |
core infrastructure + isolated provider modules
```

Rules:

1. UI imports domain contracts and Riverpod providers, never concrete provider
   API clients.
2. Provider modules implement `MusicCatalogProvider`, `AudioSourceResolver`,
   and optionally `ProviderAuthService`.
3. Provider modules do not import feature widgets.
4. Playback operates on `UnifiedTrack`, `TrackSource`, and
   `ResolvedAudioSource`; it does not know provider endpoints.
5. Drift stores stable metadata and references. It never stores a resolved
   stream URL, token, cookie, or password.

## Source tree

```text
lib/
  app/                 router, DI providers, root application
  core/
    database/          Drift schema and playback persistence
    errors/            typed cross-provider errors
    networking/        configured Dio boundary
    playback/          media_kit engine and PlaybackService
    security/          secure token repository and redaction
    utils/             known-domain URL validation
  domain/
    entities/          Freezed immutable models
    providers/         provider contracts
    repositories/      persistence and secure token contracts
    services/          source selection policy
  providers/
    common/            registry
    youtube/           isolated manifest; implementation deferred
    yandex/            isolated manifest; implementation deferred
    soundcloud/        isolated manifest; implementation deferred
  features/            feature-first UI
  shared/              adaptive shell, theme, reusable widgets
```

## Provider contracts

`MusicCatalogProvider` owns catalog lookup and public URL resolution.
`AudioSourceResolver` converts a stable `TrackSource` into an ephemeral
`ResolvedAudioSource`. `ProviderAuthService` is optional: capabilities declare
what is actually supported.

No caller assumes that a provider supports authentication, library access,
playlists, recommendations, or direct audio resolution.

## Playback

`MediaKitPlaybackEngine` owns exactly one media_kit `Player`.
`PlaybackService` owns:

- the provider-neutral queue;
- current index, progress, duration, volume, shuffle, and repeat state;
- Riverpod-observable state;
- resolved source cache;
- provider fallback order;
- persisted queue/index/volume;
- retry hooks for expired or failed sources.

Resolution flow:

```text
UnifiedTrack
  -> preferred provider
  -> last successful provider for this track
  -> configured fallback order
  -> resolver
  -> temporary ResolvedAudioSource
  -> cache only until expiresAt
  -> media_kit Media(streamUrl, httpHeaders)
```

When media_kit reports an error, the active cache entry is invalidated and the
service resolves again while preserving position. If that fails, the remaining
sources are attempted. Real HTTP 401/403 classification will be added with the
first network resolver.

The bundled test tone uses `DemoAudioSourceResolver` and
`asset:///assets/audio/resonance_test.wav`. It does not pretend to be a real
SoundCloud API implementation.

`ResonanceAudioHandler` maps the playback service to `audio_service` media
controls. The handler is deliberately not registered as an Android background
service until Stage 6, when notification/channel/manifest lifecycle is added
and tested together.

## Database

Schema version: 1.

Tables:

- `stored_tracks`;
- `stored_track_sources`;
- `local_playlists`;
- `local_playlist_tracks`;
- `favorite_tracks`;
- `listening_history_entries`;
- `search_history_entries`;
- `provider_preferences`;
- `playback_queue_entries`;
- `cached_metadata_entries`.

Indexes cover normalized title/artist matching, source joins, playlist
positions, listening/search recency, and metadata expiry. Foreign keys are
enabled on open. Future upgrades must increment `schemaVersion` and add a
targeted `onUpgrade` branch.

`cached_metadata_entries` may store non-sensitive response metadata and playback
session settings. It may not store resolved stream URLs or credentials.

## Security

- Provider tokens use `flutter_secure_storage` through
  `SecureTokenRepository`.
- Tokens are provider-scoped and trimmed before writing.
- No token value is logged.
- Sensitive header names are redacted before future crash/network reporting.
- Public and stream URLs must be parsed as `Uri` and validated against
  provider-specific domain allowlists before network use.
- Dio has bounded connect/send/receive timeouts and redirect limits.

## Platform strategy

Flutter feature and domain layers are platform-neutral. Native concerns sit
behind plugins and small adapters:

- Windows and Android are generated now;
- Linux/macOS/iOS can be added with `flutter create --platforms=... .`;
- background audio and media sessions remain behind `audio_service`,
  `audio_session`, and `PlaybackEngine`.

## YouTube boundary

YouTube is intentionally different from Yandex and SoundCloud. The supported
implementation uses YouTube Data API search and a visible official IFrame
Player hosted inside a platform WebView. It does not extract an audio-only URL,
does not feed YouTube media into `media_kit`, does not hide the player or its
branding, and does not continue YouTube playback when the application is
closed or minimized.

The next YouTube stage is therefore:

1. add a server-side `YOUTUBE_API_KEY` and normalized Data API search adapter;
2. mark results as `MusicProvider.youtube` and retain the video ID;
3. open a dedicated visible player mode using the official IFrame API;
4. pass app identity/Referer information required by embedded playback;
5. keep the existing `PlaybackService` audio resolver unchanged for Yandex and
   SoundCloud;
6. add platform WebView and policy-compliance tests before enabling the source.
