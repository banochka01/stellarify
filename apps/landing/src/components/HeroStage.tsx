import { useEffect, useRef, useState } from "react";
import gsap from "gsap";

type StageTrack = {
  title: string;
  artist: string;
  source: string;
  sourceLogo: string;
  sourceColor: string;
  cover: string;
  glow: string;
  accent: string;
};

const sourceLogos: Record<string, string> = {
  "Яндекс Музыка": "/assets/logos/yandex-music.svg",
  SoundCloud: "/assets/logos/soundcloud.svg",
  YouTube: "/assets/logos/youtube.svg",
  Spotify: "/assets/logos/spotify.svg",
  "VK Музыка": "/assets/logos/vk.svg"
};

const tracks: StageTrack[] = [
  {
    title: "Alpha House",
    artist: "Knucks & Venna",
    source: "Spotify",
    sourceLogo: sourceLogos.Spotify,
    sourceColor: "#1db954",
    cover: "/assets/covers/alpha-house.jpg",
    glow: "109, 90, 230",
    accent: "#a795ff"
  },
  {
    title: "Большие бабки",
    artist: "OG Buda & Scally Milano",
    source: "Яндекс Музыка",
    sourceLogo: sourceLogos["Яндекс Музыка"],
    sourceColor: "#ffd234",
    cover: "/assets/covers/bolshie-babki.jpg",
    glow: "39, 181, 103",
    accent: "#ffd234"
  },
  {
    title: "Подруга Подруг",
    artist: "SLIME & FACE",
    source: "VK Музыка",
    sourceLogo: sourceLogos["VK Музыка"],
    sourceColor: "#4c8ef9",
    cover: "/assets/covers/podruga-podrug.jpg",
    glow: "239, 85, 112",
    accent: "#ff9fb0"
  },
  {
    title: "Выходной",
    artist: "MONATIK",
    source: "VK Музыка",
    sourceLogo: sourceLogos["VK Музыка"],
    sourceColor: "#4c8ef9",
    cover: "/assets/covers/vyhodnoy.jpg",
    glow: "242, 160, 61",
    accent: "#ffd9a0"
  }
];

const ROTATE_MS = 5200;

export function HeroStage() {
  const root = useRef<HTMLDivElement>(null);
  const indexRef = useRef(0);
  const animRef = useRef<gsap.core.Timeline | null>(null);
  const [index, setIndex] = useState(0);

  useEffect(() => {
    const el = root.current;
    if (!el) return;
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce) return;

    const timer = window.setInterval(() => {
      goTo((indexRef.current + 1) % tracks.length);
    }, ROTATE_MS);
    return () => window.clearInterval(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const t = tracks[index];
    gsap.to(root.current, {
      "--stage-glow-a": `rgba(${t.glow}, .48)`,
      "--stage-glow-b": `rgba(${t.glow}, .17)`,
      "--stage-accent": t.accent,
      duration: 1.3,
      ease: "power2.out",
      overwrite: "auto"
    });
  }, [index]);

  const goTo = (next: number) => {
    if (next === indexRef.current || animRef.current?.isActive()) return;
    const swap = () => {
      indexRef.current = next;
      setIndex(next);
    };
    const tl = gsap.timeline();
    tl.to("[data-stage-swap]", {
      y: -26,
      autoAlpha: 0,
      duration: 0.36,
      ease: "power2.in",
      stagger: 0.05
    })
      .add(swap)
      .fromTo(
        "[data-stage-swap]",
        { y: 30, autoAlpha: 0 },
        { y: 0, autoAlpha: 1, duration: 0.55, ease: "power3.out", stagger: 0.06 }
      );
    animRef.current = tl;
  };

  const track = tracks[index];
  const upNext = tracks
    .map((t, i) => ({ t, i }))
    .filter(({ i }) => i !== index)
    .slice(0, 3);

  return (
    <div className="stage-wrap" ref={root}>
      <div className="stage-glow stage-glow-a" aria-hidden />
      <div className="stage-glow stage-glow-b" aria-hidden />

      <div className="stage-card">
        <div className="stage-cover" data-stage-swap>
          <img src={track.cover} alt={`Обложка: ${track.title} — ${track.artist}`} />
          <span className="stage-cover-label">Resonance · Session</span>
          <span className="stage-cover-eq" aria-hidden>
            <i /><i /><i /><i />
          </span>
        </div>

        <div className="stage-side">
          <span className="stage-badge" data-stage-swap>
            <img src={track.sourceLogo} alt="" width={15} height={15} />
            {track.source}
          </span>
          <p className="stage-now-title" data-stage-swap>{track.title}</p>
          <p className="stage-now-artist" data-stage-swap>{track.artist}</p>

          <div className="stage-upnext" data-stage-swap>
            <p className="stage-upnext-label">Далее в сессии</p>
            {upNext.map(({ t, i }) => (
              <button
                key={t.title}
                type="button"
                className="stage-upnext-row"
                onClick={() => goTo(i)}
              >
                <img className="stage-upnext-cover" src={t.cover} alt="" width={40} height={40} />
                <span className="stage-upnext-title">{t.title}</span>
                <span className="stage-upnext-artist">{t.artist}</span>
              </button>
            ))}
          </div>
        </div>

        <div className="stage-progress" data-stage-swap aria-hidden>
          <span key={index} className="stage-progress-fill" />
        </div>
      </div>
    </div>
  );
}
