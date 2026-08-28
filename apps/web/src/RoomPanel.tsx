import { Copy, Headphones, Radio, Users, X } from "lucide-react";
import { useState } from "react";
import type { RoomState } from "./types";

type RoomPanelProps = {
  connected: boolean;
  room: RoomState | null;
  onClose: () => void;
  onCreate: (name: string) => void;
  onJoin: (code: string, name: string) => void;
};

export function RoomPanel({
  connected,
  room,
  onClose,
  onCreate,
  onJoin
}: RoomPanelProps) {
  const [name, setName] = useState("Stellar");
  const [code, setCode] = useState("");
  const [copied, setCopied] = useState(false);

  const copyCode = async () => {
    if (!room) return;
    await navigator.clipboard.writeText(room.code);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1500);
  };

  return (
    <aside className="room-panel" aria-label="Комната совместного прослушивания">
      <header>
        <div>
          <p className="eyebrow">Stellar rooms</p>
          <h2>{room ? "Вы в эфире" : "Слушайте вместе"}</h2>
        </div>
        <button className="icon-button" onClick={onClose} aria-label="Закрыть комнату">
          <X size={19} />
        </button>
      </header>

      {room ? (
        <>
          <div className="room-code-card">
            <span className="live-pill"><Radio size={13} /> LIVE</span>
            <p>Код комнаты</p>
            <button onClick={copyCode}>
              {room.code} <Copy size={16} />
            </button>
            <small>{copied ? "Скопировано" : "Отправьте код другу"}</small>
          </div>

          <div className="participants">
            <div className="section-line">
              <span>Слушатели</span>
              <span>{room.participants.length}</span>
            </div>
            {room.participants.map((participant, index) => (
              <div className="participant" key={participant.id}>
                <span className={`avatar avatar-${(index % 3) + 1}`}>
                  {participant.name.slice(0, 1).toUpperCase()}
                </span>
                <div>
                  <strong>{participant.name}</strong>
                  <small>{participant.id === room.hostId ? "Ведущий" : "Слушает"}</small>
                </div>
                <span className="pulse-dot" />
              </div>
            ))}
          </div>

          <div className="sync-note">
            <Headphones size={18} />
            <p>
              Синхронизируем команды плеера. Каждый слушает через свой аккаунт
              музыкального сервиса.
            </p>
          </div>
        </>
      ) : (
        <>
          <div className={`connection-state ${connected ? "online" : ""}`}>
            <span />
            {connected ? "Сервер комнат подключён" : "Сервер комнат недоступен"}
          </div>
          <label className="field-label">
            Ваше имя
            <input value={name} onChange={(event) => setName(event.target.value)} maxLength={32} />
          </label>
          <button className="primary-button wide" disabled={!connected} onClick={() => onCreate(name)}>
            <Users size={18} />
            Создать комнату
          </button>
          <div className="or-divider"><span>или войти по коду</span></div>
          <label className="field-label">
            Код комнаты
            <input
              value={code}
              onChange={(event) => setCode(event.target.value.toUpperCase())}
              placeholder="A1B2C3"
              maxLength={6}
            />
          </label>
          <button
            className="secondary-button wide"
            disabled={!connected || code.length < 6}
            onClick={() => onJoin(code, name)}
          >
            Подключиться
          </button>
        </>
      )}
    </aside>
  );
}

