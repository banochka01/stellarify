# Resonance option 2 design QA

## Visual target

- Selected direction: `C:\Users\monyx\.codex\generated_images\01a039e1-4926-7402-a6f8-944c6d71883a\exec-bffd5fba-31a6-4864-af40-4c2477ef3540.png`
- Viewport: reference normalized to 1440 x 1024; Flutter capture rendered at 1440 x 1024.
- Core language: cinematic artwork, narrow near-black navigation, coral active state, large light typography, right recent rail, compact next-track pill, and a full-width bottom player.

## Implementation evidence

- Desktop implementation: `K:\bankafy\resonance\test\goldens\resonance-home-desktop.png`
- Same-input comparison: `K:\bankafy\resonance\.qa\option-2-comparison.png`
- Mobile search: `K:\bankafy\resonance\test\goldens\resonance-search-mobile.png`
- Full-screen player: `K:\bankafy\resonance\test\goldens\resonance-player-desktop.png`
- Clean cinematic background: `K:\bankafy\resonance\assets\images\resonance_cinematic_background.png`

## Comparison history

1. First comparison found an abrupt dark-panel seam, a square artwork crop that made the subject too large, the desktop player beginning after the sidebar, and the recent action falling to the bottom edge.
2. The shell was changed so the bottom player spans the full window, Settings returned to the main navigation group, and the recent rail became content-sized.
3. The supplied square artwork was outpainted into a clean wide asset with the same subject on the right and usable negative space on the left. No UI, text, logo, or decorative control was baked into the asset.
4. Final same-input comparison confirmed the selected hierarchy, proportions, artwork placement, navigation geometry, recent rail, next-track pill, and bottom player. The decorative waveform from the concept is represented by the real interactive playback progress line.

## Functional design checks

- Search launcher navigates to live provider search.
- Primary play, pause, previous, and next controls call `PlaybackService`.
- Recent and favorite tracks start real playback.
- The heart persists to Drift and updates across the search, player bar, and library.
- Local playlists can be created, filled, opened, played from a selected index, and deleted.
- The queue is not exposed as a screen or panel; only the compact `Далее:` pill is visible.
- Mobile uses a responsive vertical composition without clipping.

## Validation

- `flutter analyze`: passed with no issues.
- `flutter test`: 28 tests passed.
- Visual goldens: desktop home, mobile search, and desktop full-screen player passed.
- Database tests cover favorite add/remove and ordered, duplicate-safe local playlists.

No actionable P0, P1, or P2 visual defects remain in the deterministic desktop and mobile states.

final result: passed
