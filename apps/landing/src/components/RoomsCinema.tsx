import { useEffect, useState } from "react";
import { Radio } from "lucide-react";
import { useInView, useReducedMotion } from "../hooks";

const TRACKS = [
  { title: "так совпало", meta: "wavescale · Яндекс Музыка", cover: "/assets/covers/tak-sovpalo.jpg" },
  { title: "Выходной", meta: "MONATIK · VK Музыка", cover: "/assets/covers/vyhodnoy.jpg" }
];

const TRACK_SECONDS = 7;

/** Listening-room mock: listeners join, the shared track plays and hands over to the next one. */
export function RoomsCinema() {
  const [ref, inView] = useInView<HTMLDivElement>();
  const reduce = useReducedMotion();
  const [seen, setSeen] = useState(false);
  const [current, setCurrent] = useState(0);

  useEffect(() => {
    if (inView) setSeen(true);
  }, [inView]);

  useEffect(() => {
    if (!inView || reduce) return;
    const timer = window.setInterval(() => setCurrent((index) => (index + 1) % TRACKS.length), TRACK_SECONDS * 1000);
    return () => window.clearInterval(timer);
  }, [inView, reduce]);

  return (
    <div className={`room-mock${seen ? " is-in" : ""}${inView ? "" : " is-paused"}`} ref={ref}>
      <div className="room-mock-head">
        <span className="room-mock-live">В эфире</span>
        <span className="room-mock-members">4 слушателя</span>
      </div>
      <div className="room-tracks" aria-live="off">
        {TRACKS.map((track, index) => (
          <div className={`room-track${index === current ? " is-current" : ""}`} key={track.title} aria-hidden={index !== current}>
            <img className="room-mock-cover" src={track.cover} alt="" width={58} height={58} loading="lazy" decoding="async" />
            <div>
              <p className="room-mock-title">{track.title}</p>
              <p className="room-mock-artist">{track.meta}</p>
            </div>
          </div>
        ))}
      </div>
      <div className="room-mock-progress">
        <span key={current} style={{ animationDuration: `${TRACK_SECONDS}s` }} />
      </div>
      <ul className="room-mock-avatars" aria-label="Слушатели">
        <li>МК</li>
        <li>АД</li>
        <li>ЛС</li>
        <li className="room-mock-you">Ты</li>
      </ul>
      <p className="room-sync"><Radio size={15} aria-hidden /> Синхронизировано · задержка 12 мс</p>
    </div>
  );
}
