# Resonance landing design QA

## Visual target

- Selected landing direction: `C:\Users\monyx\.codex\generated_images\01a039e1-4926-7402-a6f8-944c6d71883a\exec-f883d28f-c867-4b40-8475-2090a011ff62.png`
- Production URL: `https://music.webcordes.ru/`
- Art direction: black editorial canvas, bone display typography, coral emphasis, cinematic generated music artwork, large negative space, and scroll-led pacing.

## Implementation evidence

- Hero asset: `K:\bankafy\apps\landing\public\assets\resonance-hero-orbit.png`
- Source-map asset: `K:\bankafy\apps\landing\public\assets\resonance-source-map.png`
- Interface asset: `K:\bankafy\apps\landing\public\assets\resonance-app-editorial.png`
- Responsive implementation: `K:\bankafy\apps\landing\src\App.tsx` and `K:\bankafy\apps\landing\src\styles.css`.

## Comparison and interaction notes

- The hero preserves the selected oversized editorial headline, coral focal word, black negative space, and right-weighted generated artwork.
- The Cyrillic display face uses Roboto Flex with a widened axis and light weight, matching the supplied open grotesk reference instead of the previous condensed display face.
- Feature, interface, proxy/privacy, and CTA sections extend the same visual grammar without introducing unrelated card or glass styles.
- GSAP ScrollTrigger reveals the next section as it enters the viewport; live-browser inspection confirmed the visible-state transition after a 780 px scroll.
- Navigation anchors and Windows/Android CTAs resolve to the intended sections and production downloads.
- At the 390 px browser breakpoint the desktop navigation is removed while the primary download CTA, heading, and both platform links remain available.
- `prefers-reduced-motion` disables scroll animation and leaves content readable.

## Validation

- TypeScript check and 0.1.2 production build passed.
- Production TLS, CSP, landing HTML, assets, API routes, and both download routes passed HTTP checks.
- Production browser DOM loaded with the expected headings and CTAs; console warnings/errors were empty before and after scrolling.

final result: passed
