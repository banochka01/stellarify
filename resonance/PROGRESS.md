# Progress

## Version 0.3.1 — safe synchronization and audio output routing

Status: released to production and publicly verified on 2026-08-29.

- [x] Account-bound requests and stale-session rejection
- [x] Serialized local mutations and guaranteed outbox follow-up passes
- [x] Unified invalid-session cleanup
- [x] Per-user sync rate limiting and cloud-library quotas
- [x] Atomic account registration and refresh rotation
- [x] Concurrent account-switch and in-flight mutation regression tests
- [x] Live audio output enumeration and Settings device selector
- [x] Persisted headphones, speakers, and system-default routing
- [x] Windows, Android, and unsigned iOS production client builds
- [x] Atomic VPS deployment with rollback backup and public health/version/download verification
- [x] GitHub Actions release run `33241976126`

## Version 0.3.0 — accounts and library synchronization

Status: release 0.3.0 deployed to production and publicly verified on 2026-08-29.

- [x] Email/password account registration and login
- [x] Scrypt password hashing and revocable rotating sessions
- [x] User-scoped favorites and playlist storage
- [x] Idempotent operation-based library synchronization
- [x] Offline local outbox and first-account library migration
- [x] Account UI and manual synchronization action
- [x] Production Windows, Android, and unsigned iOS client builds
- [x] Atomic VPS deployment with rollback and public account-sync smoke test
- [x] Public download, checksum, API health, and container health verification

## Version 0.2.0 — first-run setup

Status: release 0.2.0 deployed to production and publicly verified on 2026-08-29.

- [x] Four-step adaptive onboarding
- [x] Provider selection and live credential validation
- [x] Server-credential readiness states and offline-safe skipping
- [x] Theme and playback-quality selection
- [x] Optional Yandex Music / YouTube playlist import
- [x] Secure persistence and playback quality wiring
- [x] Mobile first-run widget coverage
- [x] Resonance Wave architecture and staged delivery plan

## Stage 1 — foundation

Status: implemented and validated.

### Completed

- [x] Flutter project for Windows and Android
- [x] Compatible stable dependency set and lockfile
- [x] Dark adaptive desktop/mobile application shell
- [x] Riverpod dependency graph and playback state stream
- [x] GoRouter navigation
- [x] Freezed/json_serializable domain models
- [x] Provider capabilities and contracts
- [x] Isolated YouTube/Yandex/SoundCloud module boundaries
- [x] Drift schema version 1, foreign keys, indexes, and queue persistence
- [x] Secure provider token repository
- [x] Dio client defaults and URL allowlist
- [x] One media_kit Player through `MediaKitPlaybackEngine`
- [x] Local generated WAV playback resolver
- [x] Queue, progress, volume, next/previous, shuffle, and repeat
- [x] Source ordering, ephemeral cache, expiry, retry, and fallback foundation
- [x] audio_service handler boundary and Android audio-focus coordinator
- [x] Unit, database, playback integration-style, and widget smoke tests
- [x] `ARCHITECTURE.md`

### Validation completed

- `dart run build_runner build`: passed
- `dart format .`: passed
- `flutter analyze`: passed, no issues
- `flutter test`: passed, 14 tests
- `flutter build apk --debug`: passed
- Android artifact: `build/app/outputs/flutter-apk/app-debug.apk`

### Environment-limited check

- `flutter build windows --debug`: blocked by the installed Visual Studio Build
  Tools, not Dart code. `flutter_secure_storage_windows` requires `atlstr.h`;
  the “C++ ATL for latest v143 build tools” component is absent. `flutter
  doctor -v` independently reports the Visual Studio installation as
  incomplete.

### Deferred by stage boundary

- Real YouTube, Yandex Music, and SoundCloud traffic
- Provider authentication screens
- Combined search and track matching
- CRUD UI for playlists, favorites, and history
- Android background service registration and notification
- Windows system media transport controls

## Next exact task — Stage 2

Implement a replaceable YouTube extractor client, `YouTubeProvider`, and
`YouTubeAudioSourceResolver`; add mocked contract tests for search, metadata,
Opus/AAC quality selection, expiring URLs, and typed unavailable/private/
age-restricted/region-blocked errors; then register the module in
`ProviderRegistry` and prove real playback without changing `PlaybackService`.
