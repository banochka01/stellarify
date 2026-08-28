# Resonance Wave

## Product goal

Resonance Wave is an endless, provider-aware queue that adapts to listening
behavior without hiding where a track comes from. The first version should
answer one action on Home: **Start my wave**. A compact setup sheet can then
adjust mood, discovery level, language, and activity.

The feature must not be implemented as a static playlist. It continuously
loads small batches, records feedback, avoids recent repeats, and resolves each
track through the existing provider-neutral playback boundary.

## Two complementary modes

### 1. Provider-personalized wave

When a user has connected Yandex Music, the server can adapt its existing
`YandexAdapter` to the Rotor methods already exposed by
`@dvxch/yandex-music`:

1. call `rotorWaveSettings()` to discover the user's default station and the
   restrictions actually available to that account;
2. optionally call `rotorStationSettings2()` with mood/energy, diversity and
   language selected in Resonance;
3. call `rotorStationTracks(stationId)` and retain `batchId` and
   `radioSessionId` only for the active session;
4. map every sequence track to the existing `ProviderTrack` contract;
5. send `radioStarted`, `trackStarted`, `trackFinished`, and `skip` feedback
   with the matching batch id;
6. request the next batch with the last played track as the queue cursor.

Rotor is an authenticated, provider-specific integration rather than a public
stable Resonance contract. It must sit behind a `WaveProvider` adapter, be
covered by mocked contract tests, and fail over cleanly when its upstream
response changes. Personal OAuth tokens continue to arrive in the existing
provider-scoped header and are never persisted on the server.

### 2. Resonance-native wave

The fallback and future cross-provider mode builds its own candidate pool from:

- local favorites and listening history stored in Drift;
- completion ratio, early skips, repeats, and explicit dislike feedback;
- recently played artists, albums, and providers;
- a user-selected seed track, playlist, or artist;
- time of day and the explicit activity/mood selected by the user;
- candidates returned by provider adapters that are currently playable.

The first ranking model should stay explainable. A practical score is:

```text
score = tasteMatch * 0.35
      + discoveryFit * 0.20
      + contextFit * 0.15
      + playableConfidence * 0.15
      + providerDiversity * 0.10
      + freshness * 0.05
      - recentTrackPenalty
      - recentArtistPenalty
      - skipPenalty
```

This can run locally for small candidate sets. A server-side model becomes
useful only after Resonance has enough consented, anonymized feedback to train
one; telemetry must be opt-in and is not required for the MVP.

## Proposed contracts

The domain layer should add:

```text
WaveProvider
  start(WaveRequest) -> WaveBatch
  next(WaveCursor) -> WaveBatch
  feedback(WaveFeedback) -> void

WaveRequest
  seed, mood, activity, diversity, language, enabledProviders

WaveBatch
  sessionId, items, cursor, expiresAt

WaveFeedback
  eventId, sessionId, trackId, provider, started/finished/skipped/liked/disliked,
  playedDuration
```

Suggested backend routes:

```text
POST /api/v1/wave/sessions
POST /api/v1/wave/sessions/:id/next
POST /api/v1/wave/sessions/:id/feedback
DELETE /api/v1/wave/sessions/:id
```

Session state is short-lived and bounded. Feedback calls use a client-generated
`eventId` so retries are idempotent.

## Client integration

`WaveController` owns the wave session but not audio playback. It fills the
existing `PlaybackService` queue and asks for another batch when three playable
items remain. This preserves one `media_kit.Player`, current media controls,
source expiry handling, rooms, and queue persistence.

Wave mode adds three player actions:

- dislike: remove the current recommendation and send negative feedback;
- tune: open mood/activity/diversity/language controls;
- stop wave: keep already queued tracks but stop automatic replenishment.

Rooms should share the host's resulting queue, not the host's OAuth identity or
personal recommendation profile.

## Delivery stages

1. **Yandex vertical slice:** Rotor adapter, session endpoints, feedback,
   `WaveController`, Home button, and mocked contract tests.
2. **Resonance fallback:** local history/skip signals, deterministic ranker,
   recent-repeat protection, and offline-safe queue continuation.
3. **Cross-provider candidates:** provider-specific related-track adapters and
   availability-aware source matching.
4. **Polish:** tuning sheet, explanations such as “because you liked…”, room
   integration, and optional privacy-preserving telemetry.

## Acceptance gate for stage 1

- no Yandex token is logged or stored server-side;
- upstream Rotor errors produce a typed unavailable response and do not break
  ordinary search/playback;
- a wave requests another batch before queue exhaustion;
- skip and finished feedback contain the correct session and batch ids;
- resolved audio is proven with the native player and advancing position;
- Android and Windows layouts pass real narrow/wide runtime checks.
