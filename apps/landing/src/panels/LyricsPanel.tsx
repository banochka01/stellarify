import { ArrowRight } from "lucide-react";
import { LyricsCinema } from "../components/LyricsCinema";

export default function LyricsPanel() {
  return (
    <div className="panel-split">
      <LyricsCinema />
      <div className="panel-stack">
        <div className="panel-intro">
          <p className="eyebrow">Один выразительный плеер</p>
          <h3 className="panel-title">Не ещё один клон стриминга.</h3>
          <p>
            Один нативный плеер Resonance для всех разрешённых источников:
            Flow-переходы, выравнивание громкости, живая очередь, lyrics и
            стабильное адаптивное управление на каждом экране.
          </p>
          <a className="panel-link" href="/downloads/windows">Попробовать Resonance <ArrowRight size={17} /></a>
        </div>
        <figure className="panel-shot">
          <img src="/assets/resonance-app-editorial.png" alt="Интерфейс Resonance: поиск и плеер" loading="lazy" />
        </figure>
      </div>
    </div>
  );
}
