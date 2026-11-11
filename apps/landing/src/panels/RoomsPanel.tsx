import { Link2, ListMusic, Radio } from "lucide-react";
import { RoomsCinema } from "../components/RoomsCinema";

export default function RoomsPanel() {
  return (
    <div className="panel-split">
      <div className="panel-stack">
        <div className="panel-intro">
          <p className="eyebrow">Слушать вместе</p>
          <h3 className="panel-title">Одна очередь. <em>Все</em> синхронно.</h3>
          <p>
            Комната синхронизирует воспроизведение у каждого участника:
            пауза, перемотка и живая очередь общие. Слушайте одновременно,
            где бы вы ни находились.
          </p>
        </div>
        <ul className="point-list">
          <li>
            <span className="point-icon"><Radio size={22} aria-hidden /></span>
            <h4>Живая синхронизация</h4>
            <p>Пауза, перемотка и смена трека мгновенно применяются у всех участников комнаты.</p>
          </li>
          <li>
            <span className="point-icon"><Link2 size={22} aria-hidden /></span>
            <h4>Приглашение ссылкой</h4>
            <p>Создатель комнаты делится ссылкой — друзья присоединяются в один клик.</p>
          </li>
          <li>
            <span className="point-icon"><ListMusic size={22} aria-hidden /></span>
            <h4>Общая очередь</h4>
            <p>Очередь одна на всех: добавляйте треки из любого подключённого источника.</p>
          </li>
        </ul>
        <p className="panel-note">Комнаты доступны бесплатно всем пользователям с аккаунтом Resonance.</p>
      </div>
      <RoomsCinema />
    </div>
  );
}
