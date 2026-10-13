import { useLayoutEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { Music, Sparkles } from "lucide-react";
import { SESSION_TRACKS, type SessionTrack } from "../session";

gsap.registerPlugin(ScrollTrigger);

const PROMPT = "вечерний фокус: спокойнее и немного нового";

const TRACKS: SessionTrack[] = [
  SESSION_TRACKS[0],
  SESSION_TRACKS[1],
  SESSION_TRACKS[2],
  SESSION_TRACKS[3],
  SESSION_TRACKS[5],
  SESSION_TRACKS[7]
];

export function QueueCinema() {
  const root = useRef<HTMLDivElement>(null);

  useLayoutEffect(() => {
    const container = root.current;
    if (!container) return;
    const context = gsap.context(() => {
      const media = gsap.matchMedia();
      media.add(
        { reduce: "(prefers-reduced-motion: reduce)" },
        ({ conditions }) => {
          const { reduce } = conditions as { reduce: boolean };
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
          // Embedded in a tab panel: play once when visible (no scroll pinning).
          ScrollTrigger.create({
              trigger: stage,
              start: "top 74%",
              once: true,
              onEnter: () => timeline.play()
            });
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
                  {track.cover ? (
                    <img className="queue-row-cover queue-row-cover-img" src={track.cover} alt="" loading="lazy" />
                  ) : (
                    <span className="queue-row-cover" style={{ background: track.tint }}><Music size={17} /></span>
                  )}
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
