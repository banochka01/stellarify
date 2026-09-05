import { useLayoutEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { Music, Sparkles } from "lucide-react";

gsap.registerPlugin(ScrollTrigger);

const PROMPT = "вечерний фокус: спокойнее и немного нового";

const TRACKS = [
  { title: "Halcyon", artist: "Salt Harvest", source: "SoundCloud" },
  { title: "Тихий свет", artist: "Муры", source: "Яндекс Музыка" },
  { title: "Low Tide", artist: "Marén", source: "Spotify" },
  { title: "Стеклянный воздух", artist: "Полночь", source: "VK Музыка" },
  { title: "Amber Room", artist: "Odyl", source: "SoundCloud" },
  { title: "Сонце", artist: "Далёко", source: "Яндекс Музыка" }
];

export function QueueCinema() {
  const root = useRef<HTMLDivElement>(null);

  useLayoutEffect(() => {
    const container = root.current;
    if (!container) return;
    const context = gsap.context(() => {
      const media = gsap.matchMedia();
      media.add(
        { reduce: "(prefers-reduced-motion: reduce)", desktop: "(min-width: 900px)" },
        ({ conditions }) => {
          const { reduce, desktop } = conditions as { reduce: boolean; desktop: boolean };
          const stage = container.querySelector<HTMLElement>(".cinema-stage");
          const promptEl = container.querySelector<HTMLElement>(".queue-prompt-text");
          if (!stage) return;
          const rows = Array.from(container.querySelectorAll<HTMLElement>(".queue-row"));
          if (reduce) {
            if (promptEl) promptEl.textContent = PROMPT;
            gsap.set(".queue-panel", { autoAlpha: 1, y: 0 });
            gsap.set(rows, { autoAlpha: 1, y: 0 });
            return;
          }
          gsap.set(".queue-panel", { autoAlpha: 0, y: 30 });
          gsap.set(rows, { autoAlpha: 0, y: 26 });
          const timeline = gsap.timeline({ paused: true, defaults: { ease: "power2.out" } });
          const state = { n: 0 };
          timeline.to(".queue-panel", { autoAlpha: 1, y: 0, duration: 0.6 }, 0);
          timeline.to(
            state,
            {
              n: PROMPT.length,
              duration: 2.4,
              ease: "none",
              onUpdate: () => {
                if (promptEl) promptEl.textContent = PROMPT.slice(0, Math.round(state.n));
              }
            },
            0.35
          );
          rows.forEach((row, i) => {
            timeline.to(row, { autoAlpha: 1, y: 0, duration: 0.55 }, 0.9 + i * 0.5);
          });
          timeline.to({}, { duration: 0.7 });
          if (desktop) {
            ScrollTrigger.create({
              trigger: container,
              start: "top top",
              end: "bottom bottom",
              scrub: 0.6,
              animation: timeline
            });
          } else {
            ScrollTrigger.create({
              trigger: stage,
              start: "top 74%",
              once: true,
              onEnter: () => timeline.play()
            });
          }
        }
      );
      return () => media.revert();
    }, root);
    return () => context.revert();
  }, []);

  return (
    <div className="cinema-track" ref={root}>
      <div className="cinema-stage">
        <div className="queue-stage-inner">
          <p className="eyebrow">Живая очередь</p>
          <div className="queue-panel">
            <div className="queue-head">
              <Sparkles size={15} /> Wave · очередь
            </div>
            <p className="queue-prompt">
              <Sparkles size={16} />
              <span className="queue-prompt-text">{PROMPT}</span>
            </p>
            <div className="queue-list">
              {TRACKS.map((track, i) => (
                <div className="queue-row" key={track.title}>
                  <span className="queue-row-index">
                    {i === 0 ? (
                      <span className="eq"><i /><i /><i /><i /></span>
                    ) : (
                      String(i + 1).padStart(2, "0")
                    )}
                  </span>
                  <span className="queue-row-cover"><Music size={17} /></span>
                  <span>
                    <span className="queue-row-title">{track.title}</span>
                    <span className="queue-row-artist">{track.artist}</span>
                  </span>
                  <span className="queue-source" data-source={track.source}>{track.source}</span>
                </div>
              ))}
            </div>
          </div>
          <p className="cinema-caption">
            Wave собирает очередь из реальных треков подключённых источников
            и перестраивает её на лету — без выдуманных названий.
          </p>
        </div>
      </div>
    </div>
  );
}
