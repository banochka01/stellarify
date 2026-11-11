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
            VK Музыке, объединяет результаты и воспроизводит их в
            собственном плеере.
          </p>
        </div>
        <ul className="point-list">
          <li>
            <span className="point-icon"><Search size={22} aria-hidden /></span>
            <h4>Единый поиск</h4>
            <p>Один запрос — результаты из всех подключённых каталогов.</p>
          </li>
          <li>
            <span className="point-icon"><FileText size={22} aria-hidden /></span>
            <h4>Синхронные тексты</h4>
            <p>Активная строка следует за музыкой, а обычный текст остаётся доступным без таймкодов.</p>
          </li>
          <li>
            <span className="point-icon"><Heart size={22} aria-hidden /></span>
            <h4>Wave понимает контекст</h4>
            <p>«Спокойнее», «больше нового», «без этого артиста» — очередь перестраивается без выдуманных треков.</p>
          </li>
        </ul>
      </div>
      <QueueCinema />
    </div>
  );
}
