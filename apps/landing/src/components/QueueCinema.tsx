import { useEffect, useState, type CSSProperties } from "react";
import { Music } from "lucide-react";
import { useInView, useReducedMotion } from "../hooks";
import { SESSION_TRACKS, type SessionTrack } from "../session";

const PROMPT = "вечерний фокус: спокойнее и немного нового";

const TRACKS: SessionTrack[] = [
  SESSION_TRACKS[0],
  SESSION_TRACKS[1],
  SESSION_TRACKS[2],
  SESSION_TRACKS[3],
  SESSION_TRACKS[5],
  SESSION_TRACKS[7]
];

/** Wave queue mock: the prompt types itself, then the rows arrive one by one. */
export function QueueCinema() {
  const [ref, inView] = useInView<HTMLDivElement>(true);
  const reduce = useReducedMotion();
  const [typed, setTyped] = useState(0);

  useEffect(() => {
    if (!inView || reduce) return;
    const timer = window.setInterval(() => {
      setTyped((count) => {
        if (count >= PROMPT.length) {
          window.clearInterval(timer);
          return count;
        }
        return count + 1;
      });
    }, 42);
    return () => window.clearInterval(timer);
  }, [inView, reduce]);

  const done = reduce || typed >= PROMPT.length;

  return (
    <div className={`queue-demo${inView ? " is-in" : ""}`} ref={ref}>
      <div className="queue-panel">
        <p className="queue-head">Wave · очередь</p>
        <p className={`queue-prompt${done ? " is-done" : ""}`} aria-label={PROMPT}>
          <Music size={16} aria-hidden />
          <span className="queue-prompt-text" aria-hidden>{reduce ? PROMPT : PROMPT.slice(0, typed)}</span>
        </p>
        <ol className="queue-list">
          {TRACKS.map((track, i) => (
            <li className="queue-row" key={track.title} style={{ "--i": i } as CSSProperties}>
              <span className="queue-row-index" aria-hidden>
                {i === 0 ? <span className="eq"><i /><i /><i /><i /></span> : String(i + 1).padStart(2, "0")}
              </span>
              {track.cover ? (
                <img className="queue-row-cover" src={track.cover} alt="" width={44} height={44} loading="lazy" decoding="async" />
              ) : (
                <span className="queue-row-cover" style={{ background: track.tint }}><Music size={17} aria-hidden /></span>
              )}
              <span className="queue-row-text">
                <span className="queue-row-title">{track.title}</span>
                <span className="queue-row-artist">{track.artist}</span>
              </span>
              <span className="queue-source" data-source={track.source}>{track.source}</span>
            </li>
          ))}
        </ol>
      </div>
      <p className="demo-caption">
        Wave собирает очередь из реальных треков подключённых источников
        и перестраивает её на лету — без выдуманных названий.
      </p>
    </div>
  );
}
