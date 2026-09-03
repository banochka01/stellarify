# Resonance

Resonance is a Flutter foundation for a provider-based music aggregator.
The current client targets Windows, Android, and iOS. It includes a bundled
local diagnostic track plus server-backed SoundCloud and Yandex Music search
and playback. YouTube Music remains a later provider.

Version 1.2.0 adds Visual Stage: authorized video tracks can fill the screen
behind readable artwork, metadata and lyrics; Lyrics gets a dedicated cinematic
fullscreen layout; and desktop builds can expose a local-only OBS now-playing
widget without provider tokens or playback URLs.

Version 1.1.0 added Flow transitions with adaptive source-aware timing,
loudness normalization, a visual queue timeline, synchronized lyrics with a
plain-text fallback, and more natural reduced-motion-aware player animations.

Version 1.0.0 added a contextual Wave controlled with ordinary language,
account-owned musical memory, cross-device continuation, shared room taste,
explainable recommendations, and a fluid reduced-motion-aware Home interface.

Version 0.4.0 added server-enforced subscriptions: a one-day SoundCloud-only
guest trial plus Base, Plus and Family access activated by paid promo codes.
Promo codes are issued only by the configured Telegram admin bot. See
[`../deploy/SUBSCRIPTIONS.md`](../deploy/SUBSCRIPTIONS.md) for the exact
capabilities, operational requirements and release gate.

Version 0.2.0 added a four-step first-run setup for provider selection,
credential validation, appearance, playback quality, and optional playlist
import. The proposed endless recommendation flow is documented in
[WAVE_DESIGN.md](WAVE_DESIGN.md).

## Toolchain

- Flutter 3.44.4 stable
- Dart 3.12.2 stable
- Windows, Android, and generated iOS targets

## Run

```powershell
cd K:\bankafy\resonance
K:\SDK\flutter_fresh\bin\flutter.bat pub get
K:\SDK\flutter_fresh\bin\dart.bat run build_runner build
K:\SDK\flutter_fresh\bin\flutter.bat run -d windows
```

SoundCloud and Yandex Music accept a per-user OAuth token on the Resonance
Settings screen. Each token is stored in Flutter secure storage and sent only
to the selected provider request through `X-Provider-Token`. SoundCloud accepts
either a raw access token or a value prefixed with `OAuth` / `Bearer`.

SoundCloud server credentials remain an optional fallback for installations
that have a registered API application. Put them in `K:\bankafy\.env`, never in
the Flutter app or source control:

```dotenv
SOUNDCLOUD_CLIENT_ID=...
SOUNDCLOUD_CLIENT_SECRET=...
```

When no per-user SoundCloud token is supplied, the server exchanges these
values through the client-credentials flow and reuses/refreshes the resulting
access token. A rejected per-user token returns HTTP 401 and is never silently
replaced with server credentials.

`YANDEX_MUSIC_TOKEN` remains an optional server-only development fallback.

Start the backend from the repository root:

```powershell
Copy-Item .env.example .env
npm.cmd run dev:server
```

The backend address can be changed at runtime on the Resonance Settings screen,
and production release builds use `https://music.webcordes.ru` as their
compile-time default. It can still be overridden for local development:

```powershell
K:\SDK\flutter_fresh\bin\flutter.bat run -d windows --dart-define=RESONANCE_API_URL=http://localhost:8787
```

Use an HTTPS URL for production. Android emulators must use the host address
(commonly `10.0.2.2`) instead of `localhost`.

The Home screen contains a local 8-second WAV diagnostic track. It is resolved
through the same `AudioSourceResolver` boundary that future providers will use
and played by a single media_kit `Player`.

Windows builds require the Visual Studio C++ ATL component because the current
stable `flutter_secure_storage_windows` plugin includes `atlstr.h`.

iOS can only be compiled on macOS with Xcode. The local workflow
`.github/workflows/ios-unsigned.yml` builds without code signing and packages
`iOS · unsigned IPA`; the result still has to be self-signed before installation.

## Validation

```powershell
K:\SDK\flutter_fresh\bin\dart.bat format --output=none --set-exit-if-changed .
K:\SDK\flutter_fresh\bin\flutter.bat analyze
K:\SDK\flutter_fresh\bin\flutter.bat test
K:\SDK\flutter_fresh\bin\flutter.bat build windows --release
K:\SDK\flutter_fresh\bin\flutter.bat build apk --release
```

See [ARCHITECTURE.md](ARCHITECTURE.md),
[IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), and
[PROGRESS.md](PROGRESS.md).
