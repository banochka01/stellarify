import { FileText, Heart, Search } from "lucide-react";
import { QueueCinema } from "../components/QueueCinema";

export default function SearchPanel() {
  return (
    <div className="panel-split">
      <div className="panel-stack">
      <div className="panel-intro">
        <p className="eyebrow">Поиск без границ</p>
        <h3 className="panel-title">Один поиск — <em>разные</em> источники.</h3>
        <p>
          Resonance ищет музыку в SoundCloud, Яндекс Музыке, Spotify и
          VK Музыке, объединяет результаты и воспроизводит их только в
          собственном плеере.
        </p>
      </div>
      <div className="feature-row feature-row-stack">
        <article>
          <span><Search size={24} /></span>
          <h3>Единый поиск</h3>
          <p>Один запрос — результаты из всех подключённых каталогов.</p>
        </article>
        <article>
          <span><FileText size={24} /></span>
          <h3>Синхронные тексты</h3>
          <p>Активная строка следует за музыкой, а обычный текст остаётся доступным без таймкодов.</p>
        </article>
        <article>
          <span><Heart size={24} /></span>
          <h3>Wave понимает контекст</h3>
          <p>«Спокойнее», «больше нового», «без этого артиста» — очередь перестраивается без выдуманных треков.</p>
        </article>
      </div>
      </div>
      <QueueCinema />
    </div>
  );
}
