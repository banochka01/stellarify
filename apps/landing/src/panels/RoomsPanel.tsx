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
        <div className="feature-row feature-row-stack">
          <article>
            <span><Radio size={24} /></span>
            <h3>Живая синхронизация</h3>
            <p>Пауза, перемотка и смена трека мгновенно применяются у всех участников комнаты.</p>
          </article>
          <article>
            <span><Link2 size={24} /></span>
            <h3>Приглашение ссылкой</h3>
            <p>Создатель комнаты делится ссылкой — друзья присоединяются в один клик.</p>
          </article>
          <article>
            <span><ListMusic size={24} /></span>
            <h3>Общая очередь</h3>
            <p>Очередь одна на всех: добавляйте треки из любого подключённого источника.</p>
          </article>
        </div>
        <p className="rooms-note">Комнаты доступны бесплатно всем пользователям с аккаунтом Resonance.</p>
      </div>
      <RoomsCinema />
    </div>
  );
}
