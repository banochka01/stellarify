# Resonance — implementation plan

## Scope

This run implements Stage 1 only. It creates a compilable Flutter foundation
for Windows and Android without real YouTube, Yandex Music, or SoundCloud
network integrations.

The existing Stellarify web project in `K:\bankafy` remains untouched.
Resonance lives in `K:\bankafy\resonance`.

## Technical baseline

- Flutter stable from `K:\SDK\flutter_fresh`
- Dart stable bundled with Flutter
- Feature-first modules with provider integrations isolated behind domain
  contracts
- Riverpod for dependency injection and reactive state
- GoRouter for navigation
- Freezed and json_serializable for immutable domain and playback state
- Drift with SQLite for local durable data
- media_kit as the only playback engine
- flutter_secure_storage for provider credentials
- Dio for future provider API clients

Dependency versions are resolved by `flutter pub` against the installed stable
Flutter/Dart SDK so that the lockfile records a compatible set.

## Work plan

1. Bootstrap a Flutter project with Windows and Android targets.
2. Add the requested runtime and code-generation dependencies.
3. Build the dark adaptive application shell:
   - desktop sidebar, main content, queue rail, and player bar;
   - Android bottom navigation and mini-player;
   - placeholder Home, Search, Library, and Settings features.
4. Add Freezed domain models:
   - `MusicProvider`, `StreamProtocol`, and `AudioQuality`;
   - `UnifiedTrack`, `TrackSource`, and `ResolvedAudioSource`;
   - `ProviderCapabilities` and playback state.
5. Add provider contracts:
   - `MusicCatalogProvider`;
   - `AudioSourceResolver`;
   - `ProviderAuthService`.
6. Add Drift schema, migrations, indexes, DAOs, and test constructors for:
   tracks, sources, playlists, playlist tracks, favorites, listening history,
   search history, provider preferences, playback queue, and cached metadata.
7. Add security and networking foundations:
   - secure token repository;
   - redaction helper;
   - known-domain URL validation;
   - configured Dio client with timeouts and safe logging policy.
8. Add a single-instance `PlaybackService` over a media-kit engine abstraction:
   - local generated WAV test asset;
   - queue, play, pause, seek, next, previous, volume, shuffle, and repeat;
   - Riverpod state publication;
   - hooks for source resolution, expiry, retry, and future audio_service
     integration.
9. Add unit and integration-style tests for domain serialization, database
   operations, secure tokens, queue behavior, playback controls, URL expiry,
   and source ordering.
10. Write `ARCHITECTURE.md` and update `PROGRESS.md`.

## Explicit non-goals for Stage 1

- No real provider endpoints, undocumented response formats, extractors, or
  authentication flows.
- No permanent storage of stream URLs, cookies, passwords, or tokens in Drift.
- No WebView playback.
- No background playback implementation yet; only integration boundaries are
  prepared for Stage 6.
- No track matching or combined provider search yet.

## Validation gate

Stage 1 is complete only when all of these pass:

```powershell
dart run build_runner build
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

When the local toolchain permits it, Windows and Android debug builds are also
used as platform smoke checks.
