import { ArrowRight } from "lucide-react";
import { LyricsCinema } from "../components/LyricsCinema";

export default function LyricsPanel() {
  return (
    <div className="panel-split">
      <LyricsCinema />
      <div className="panel-stack">
        <div className="panel-intro">
          <p className="eyebrow">Один выразительный плеер</p>
          <h3 className="panel-title">Не ещё один <em>клон</em> стриминга.</h3>
          <p>
            Один нативный плеер Resonance для всех разрешённых источников:
            плавные переходы, выравнивание громкости, живая очередь, тексты и
            стабильное адаптивное управление на каждом экране.
          </p>
          <a className="panel-link" href="#download">Попробовать Resonance <ArrowRight size={17} aria-hidden /></a>
        </div>
        <figure className="panel-shot">
          <img
            src="/assets/resonance-app-editorial.webp"
            alt="Интерфейс Resonance: поиск по источникам, список результатов и плеер"
            width={1400}
            height={996}
            loading="lazy"
            decoding="async"
          />
        </figure>
      </div>
    </div>
  );
}
