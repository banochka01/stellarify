import { useEffect, useState } from "react";
import { useInView, useReducedMotion } from "../hooks";

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

const LINE_MS = 1900;

/** Synced-lyrics mock: the active line walks through the verse like in the player. */
export function LyricsCinema() {
  const [ref, inView] = useInView<HTMLDivElement>();
  const reduce = useReducedMotion();
  const [active, setActive] = useState(0);
  const playing = inView && !reduce;

  useEffect(() => {
    if (!playing) return;
    const timer = window.setInterval(() => setActive((index) => (index + 1) % LINES.length), LINE_MS);
    return () => window.clearInterval(timer);
  }, [playing]);

  return (
    <div className={`lyrics-demo stage${reduce ? "" : " is-synced"}`} ref={ref}>
      <p className="eyebrow">Синхронные тексты</p>
      <ol className="lyrics-lines">
        {LINES.map((line, index) => (
          <li
            key={line}
            className={`lyrics-line${index === active ? " is-active" : index < active ? " is-past" : ""}`}
            aria-current={!reduce && index === active ? "true" : undefined}
          >
            {line}
          </li>
        ))}
      </ol>
      <p className="demo-caption">
        Активная строка следует за музыкой — и в одиночном прослушивании, и в комнате.
      </p>
    </div>
  );
}
