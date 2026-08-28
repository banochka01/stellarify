# Stellarify

Stellarify is a cross-platform music hub: one library for links and playlists
from multiple providers, plus synchronized listening rooms.

The first MVP includes:

- a responsive web/PWA client;
- a Tauri 2 shell for Windows, Android, and iOS;
- playlist/link import preview for Spotify, SoundCloud, YouTube Music,
  Yandex Music, and VK Music;
- real-time room creation, joining, participant presence, and playback state;
- a provider capability layer that makes legal/technical restrictions visible.

## Run locally

```powershell
Copy-Item .env.example .env
npm.cmd install
npm.cmd run dev
```

Open `http://localhost:5173`. The API and WebSocket server use
`http://localhost:8787`.

## Checks

```powershell
npm.cmd run check
npm.cmd test
npm.cmd run build
```

## Native clients

The UI is shared across all targets through Tauri 2.

```powershell
# Windows
npm.cmd run native:dev
npm.cmd run native:build

# Android (first run only, Android SDK required)
npm.cmd run native:android:init

# iOS (first run only, must be run on macOS with Xcode)
npm.cmd run native:ios:init
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for provider and playback
boundaries.

