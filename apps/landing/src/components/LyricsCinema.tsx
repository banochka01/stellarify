import { useLayoutEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

gsap.registerPlugin(ScrollTrigger);

const LINES = [
  "Город гудит на низкой частоте,",
  "и фары режут ночь пополам.",
  "Каждый трек ложится на ритм шагов —",
  "очередь ловит тебя, как эхо.",
  "Строка загорается раньше бита,",
  "ни одной не теряя.",
  "А если бросишь «побыстрее» —",
  "ночь ускорится. Ей можно верить."
];

export function LyricsCinema() {
  const root = useRef<HTMLElement>(null);

  useLayoutEffect(() => {
    const section = root.current;
    if (!section) return;
    const context = gsap.context(() => {
      const media = gsap.matchMedia();
      media.add(
        { reduce: "(prefers-reduced-motion: reduce)" },
        ({ conditions }) => {
          const { reduce } = conditions as { reduce: boolean };
          const track = section.querySelector<HTMLElement>(".cinema-track");
          const stage = section.querySelector<HTMLElement>(".cinema-stage");
          if (!track || !stage) return;
          const lines = Array.from(section.querySelectorAll<HTMLElement>(".lyrics-line"));
          if (reduce) {
            gsap.set(lines, { autoAlpha: 1, y: 0, scale: 1 });
            return;
          }
          gsap.set(lines, { autoAlpha: 0.14, y: 14, scale: 0.985 });
          const timeline = gsap.timeline({ paused: true, defaults: { ease: "power2.out" } });
          lines.forEach((line, i) => {
            timeline.to(line, { autoAlpha: 1, y: 0, scale: 1, duration: 0.55 }, i);
            if (i < lines.length - 1) {
              timeline.to(line, { autoAlpha: 0.42, duration: 0.45 }, i + 0.8);
            }
          });
          timeline.to({}, { duration: 0.6 });
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
    <section className="cinema-section" id="lyrics" ref={root}>
      <div className="cinema-track">
        <div className="cinema-stage">
          <div className="lyrics-stage-inner">
            <p className="eyebrow">Синхронные lyrics</p>
            <ol className="lyrics-lines">
              {LINES.map((line) => (
                <li className="lyrics-line" key={line}>{line}</li>
              ))}
            </ol>
            <p className="cinema-caption">
              Активная строка следует за музыкой — и в одиночном прослушивании, и в комнате.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
