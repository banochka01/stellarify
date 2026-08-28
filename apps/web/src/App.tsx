import {
  Bell,
  ChevronRight,
  CirclePlus,
  Clock3,
  Compass,
  Heart,
  Home,
  Import,
  Library,
  ListMusic,
  Menu,
  MessageCircleMore,
  MoreHorizontal,
  Pause,
  Play,
  Plus,
  Radio,
  Search,
  Settings,
  Shuffle,
  SkipBack,
  SkipForward,
  Sparkles,
  Users,
  Volume2,
  X
} from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { io, type Socket } from "socket.io-client";
import { mixes, tracks } from "./data";
import { ImportModal } from "./ImportModal";
import { RoomPanel } from "./RoomPanel";
import type { ImportedSource, ProviderId, RoomState, Track } from "./types";

const apiUrl = import.meta.env.VITE_API_URL || "http://localhost:8787";

const providerLabels: Record<ProviderId, string> = {
  all: "Все площадки",
  spotify: "Spotify",
  soundcloud: "SoundCloud",
  youtube: "YouTube Music",
  yandex: "Яндекс Музыка",
  vk: "VK Музыка"
};

const providerMarks: Record<Exclude<ProviderId, "all">, string> = {
  spotify: "S",
  soundcloud: "SC",
  youtube: "YT",
  yandex: "Я",
  vk: "VK"
};

const navItems = [
  { icon: Home, label: "Главная", active: true },
  { icon: Compass, label: "Обзор" },
  { icon: Radio, label: "Радио" }
];

const libraryItems = [
  { icon: Library, label: "Моя медиатека" },
  { icon: Heart, label: "Любимые треки" },
  { icon: Clock3, label: "Недавно слушали" }
];

export function App() {
  const [provider, setProvider] = useState<ProviderId>("all");
  const [query, setQuery] = useState("");
  const [currentTrack, setCurrentTrack] = useState<Track>(tracks[0]!);
  const [playing, setPlaying] = useState(true);
  const [liked, setLiked] = useState(new Set(tracks.filter((track) => track.liked).map((track) => track.id)));
  const [importOpen, setImportOpen] = useState(false);
  const [roomOpen, setRoomOpen] = useState(false);
  const [room, setRoom] = useState<RoomState | null>(null);
  const [connected, setConnected] = useState(false);
  const [mobileNav, setMobileNav] = useState(false);
  const [notice, setNotice] = useState("");
  const socketRef = useRef<Socket | null>(null);

  useEffect(() => {
    const socket = io(apiUrl, { transports: ["websocket", "polling"] });
    socketRef.current = socket;
    socket.on("connect", () => setConnected(true));
    socket.on("disconnect", () => setConnected(false));
    socket.on("room:state", (nextRoom: RoomState) => {
      setRoom(nextRoom);
      const syncedTrack = tracks.find((track) => track.id === nextRoom.playback.trackId);
      if (syncedTrack) setCurrentTrack(syncedTrack);
      setPlaying(!nextRoom.playback.paused);
    });
    return () => {
      socket.disconnect();
    };
  }, []);

  useEffect(() => {
    if (!notice) return;
    const timer = window.setTimeout(() => setNotice(""), 2600);
    return () => window.clearTimeout(timer);
  }, [notice]);

  const visibleTracks = useMemo(() => {
    const search = query.trim().toLowerCase();
    return tracks.filter((track) => {
      const matchesProvider = provider === "all" || track.provider === provider;
      const matchesSearch =
        !search ||
        `${track.title} ${track.artist} ${track.album}`.toLowerCase().includes(search);
      return matchesProvider && matchesSearch;
    });
  }, [provider, query]);

  const emitPlayback = (track: Track, paused: boolean) => {
    if (!room) return;
    socketRef.current?.emit("playback:update", {
      code: room.code,
      trackId: track.id,
      provider: track.provider,
      paused,
      positionMs: 0
    });
  };

  const selectTrack = (track: Track) => {
    setCurrentTrack(track);
    setPlaying(true);
    emitPlayback(track, false);
  };

  const togglePlaying = () => {
    const next = !playing;
    setPlaying(next);
    emitPlayback(currentTrack, !next);
  };

  const createRoom = (name: string) => {
    socketRef.current?.emit("room:create", { name }, (result: { ok: boolean; room?: RoomState; error?: string }) => {
      if (result.ok && result.room) setRoom(result.room);
      else setNotice(result.error || "Не удалось создать комнату");
    });
  };

  const joinRoom = (code: string, name: string) => {
    socketRef.current?.emit("room:join", { code, name }, (result: { ok: boolean; room?: RoomState; error?: string }) => {
      if (result.ok && result.room) setRoom(result.room);
      else setNotice(result.error || "Не удалось войти в комнату");
    });
  };

  const imported = (sources: ImportedSource[]) => {
    setNotice(`Добавлено источников: ${sources.length}`);
  };

  return (
    <div className="app-shell">
      <aside className={`sidebar ${mobileNav ? "mobile-open" : ""}`}>
        <div className="brand">
          <span className="brand-mark"><Sparkles size={20} fill="currentColor" /></span>
          <span>stellarify</span>
        </div>

        <nav>
          <p className="nav-label">Меню</p>
          {navItems.map(({ icon: Icon, label, active }) => (
            <button className={active ? "active" : ""} key={label}>
              <Icon size={19} />
              {label}
            </button>
          ))}
          <p className="nav-label library-label">Коллекция</p>
          {libraryItems.map(({ icon: Icon, label }) => (
            <button key={label}>
              <Icon size={19} />
              {label}
            </button>
          ))}
        </nav>

        <div className="playlist-block">
          <div className="nav-label-row">
            <p className="nav-label">Плейлисты</p>
            <button aria-label="Создать плейлист"><Plus size={16} /></button>
          </div>
          <button><span className="playlist-cover purple">DR</span><span>Deep Rotation<small>24 трека</small></span></button>
          <button><span className="playlist-cover teal">NS</span><span>Night Signals<small>38 треков</small></span></button>
        </div>

        <button className="user-card">
          <span className="avatar avatar-main">ST</span>
          <span><strong>Stellar</strong><small>Free plan</small></span>
          <MoreHorizontal size={18} />
        </button>
      </aside>

      {mobileNav && <button className="nav-scrim" aria-label="Закрыть меню" onClick={() => setMobileNav(false)} />}

      <main>
        <header className="topbar">
          <button className="icon-button mobile-menu" onClick={() => setMobileNav(true)} aria-label="Открыть меню">
            <Menu size={21} />
          </button>
          <label className="search-box">
            <Search size={18} />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Треки, артисты, альбомы..."
            />
            <kbd>⌘ K</kbd>
          </label>
          <div className="top-actions">
            <button className="icon-button" aria-label="Уведомления"><Bell size={19} /></button>
            <button className="icon-button" aria-label="Настройки"><Settings size={19} /></button>
            <button className="room-button" onClick={() => setRoomOpen(true)}>
              <Users size={18} />
              <span>{room ? room.code : "Комната"}</span>
              {room && <i />}
            </button>
          </div>
        </header>

        <div className="content">
          <section className="hero">
            <div className="hero-orbit orbit-one" />
            <div className="hero-orbit orbit-two" />
            <div className="hero-copy">
              <p className="eyebrow"><Sparkles size={14} /> Stellar selection</p>
              <h1>Вся музыка.<br /><span>Одно пространство.</span></h1>
              <p>Соберите любимые треки со всех площадок и слушайте вместе — без переключений.</p>
              <div className="hero-actions">
                <button className="primary-button" onClick={() => selectTrack(tracks[0]!)}>
                  <Play size={18} fill="currentColor" /> Начать слушать
                </button>
                <button className="secondary-button" onClick={() => setImportOpen(true)}>
                  <Import size={18} /> Импорт плейлиста
                </button>
              </div>
            </div>
            <div className="hero-visual" aria-hidden="true">
              <div className="planet-disc">
                <div className="planet-label"><Sparkles size={24} /><span>stellarify</span></div>
              </div>
              <div className="floating-note note-one">♪</div>
              <div className="floating-note note-two">♫</div>
            </div>
          </section>

          <section className="providers-section">
            <div className="section-heading">
              <div>
                <p className="eyebrow">Подключённые миры</p>
                <h2>Музыка из ваших сервисов</h2>
              </div>
              <button onClick={() => setImportOpen(true)}>Управление <ChevronRight size={17} /></button>
            </div>
            <div className="provider-grid">
              {(["spotify", "soundcloud", "youtube", "yandex", "vk"] as const).map((id) => (
                <button
                  key={id}
                  className={`provider-card ${id} ${provider === id ? "selected" : ""}`}
                  onClick={() => setProvider(provider === id ? "all" : id)}
                >
                  <span className="provider-mark">{providerMarks[id]}</span>
                  <span><strong>{providerLabels[id]}</strong><small>{id === "spotify" || id === "soundcloud" || id === "youtube" ? "Требует подключения" : "Импорт по ссылке"}</small></span>
                  <CirclePlus size={19} />
                </button>
              ))}
            </div>
          </section>

          <section className="mixes-section">
            <div className="section-heading">
              <div>
                <p className="eyebrow">Для вас</p>
                <h2>Продолжите путешествие</h2>
              </div>
              <button>Смотреть все <ChevronRight size={17} /></button>
            </div>
            <div className="mix-grid">
              {mixes.map((mix, index) => (
                <button className="mix-card" key={mix.title} onClick={() => selectTrack(tracks[index]!)}>
                  <span className="mix-art" style={{ background: mix.color }}>
                    <span className="mix-ring" />
                    <Play className="mix-play" size={20} fill="currentColor" />
                  </span>
                  <strong>{mix.title}</strong>
                  <small>{mix.subtitle}</small>
                </button>
              ))}
            </div>
          </section>

          <section className="tracks-section">
            <div className="section-heading">
              <div>
                <p className="eyebrow">Быстрый доступ</p>
                <h2>{provider === "all" ? "Недавно слушали" : providerLabels[provider]}</h2>
              </div>
              {provider !== "all" && <button onClick={() => setProvider("all")}><X size={16} /> Сбросить</button>}
            </div>
            <div className="track-table">
              <div className="track-row track-head">
                <span>#</span><span>Название</span><span className="album-cell">Альбом</span><span className="provider-cell">Источник</span><span><Clock3 size={15} /></span><span />
              </div>
              {visibleTracks.map((track, index) => (
                <button className={`track-row ${currentTrack.id === track.id ? "current" : ""}`} key={track.id} onClick={() => selectTrack(track)}>
                  <span className="track-index">{currentTrack.id === track.id && playing ? <span className="equalizer"><i /><i /><i /></span> : index + 1}</span>
                  <span className="track-title-cell">
                    <span className="mini-cover" style={{ background: track.color }}><Sparkles size={13} /></span>
                    <span><strong>{track.title}</strong><small>{track.artist}</small></span>
                  </span>
                  <span className="album-cell">{track.album}</span>
                  <span className="provider-cell"><i className={`provider-dot ${track.provider}`} />{providerLabels[track.provider]}</span>
                  <span>{track.duration}</span>
                  <span><MoreHorizontal size={18} /></span>
                </button>
              ))}
              {visibleTracks.length === 0 && (
                <div className="empty-state"><Search size={24} /><strong>Ничего не найдено</strong><span>Попробуйте другой запрос или площадку</span></div>
              )}
            </div>
          </section>
        </div>
      </main>

      <footer className="player">
        <div className="now-playing">
          <span className="player-cover" style={{ background: currentTrack.color }}><Sparkles size={18} /></span>
          <span><strong>{currentTrack.title}</strong><small>{currentTrack.artist}</small></span>
          <button
            className={liked.has(currentTrack.id) ? "liked" : ""}
            aria-label="Нравится"
            onClick={() => {
              const next = new Set(liked);
              if (next.has(currentTrack.id)) next.delete(currentTrack.id);
              else next.add(currentTrack.id);
              setLiked(next);
            }}
          ><Heart size={18} fill={liked.has(currentTrack.id) ? "currentColor" : "none"} /></button>
        </div>
        <div className="player-center">
          <div className="player-controls">
            <button aria-label="Перемешать"><Shuffle size={16} /></button>
            <button aria-label="Предыдущий"><SkipBack size={18} fill="currentColor" /></button>
            <button className="play-button" onClick={togglePlaying} aria-label={playing ? "Пауза" : "Воспроизвести"}>
              {playing ? <Pause size={18} fill="currentColor" /> : <Play size={18} fill="currentColor" />}
            </button>
            <button aria-label="Следующий"><SkipForward size={18} fill="currentColor" /></button>
            <button aria-label="Очередь"><ListMusic size={17} /></button>
          </div>
          <div className="progress-row"><span>1:42</span><div className="progress"><i /></div><span>{currentTrack.duration}</span></div>
        </div>
        <div className="player-tools">
          {room && <button className="sync-active" onClick={() => setRoomOpen(true)}><MessageCircleMore size={18} /><span>{room.participants.length}</span></button>}
          <Volume2 size={18} />
          <div className="volume"><i /></div>
        </div>
      </footer>

      {importOpen && <ImportModal apiUrl={apiUrl} onClose={() => setImportOpen(false)} onImported={imported} />}
      {roomOpen && <RoomPanel connected={connected} room={room} onClose={() => setRoomOpen(false)} onCreate={createRoom} onJoin={joinRoom} />}
      {notice && <div className="toast">{notice}</div>}
    </div>
  );
}

