import { Album, ArrowRight, Check, Heart, Music2 } from "lucide-react";

const tracks = [
  { title: "Tadow", artist: "Masego, FKJ", tone: "ember", initials: "MF" },
  { title: "Nightcall", artist: "Kavinsky", tone: "violet", initials: "K" },
  { title: "After Dark", artist: "Mr.Kitty", tone: "crimson", initials: "M" },
  { title: "Midnight City", artist: "M83", tone: "blue", initials: "M" }
];

export function LibraryCinema() {
  return (
    <div className="panel-stack">
      <div className="panel-head">
        <div>
          <p className="eyebrow">Перенос медиатеки</p>
          <h3 className="panel-title">Забери всё. <em>Музыка</em> останется.</h3>
        </div>
        <p>
          Один перенос забирает любимые треки и плейлисты из Яндекс Музыки,
          Spotify или VK. Без ручного копирования и без потери оригиналов.
        </p>
      </div>

      <div
        className="library-cinema stage"
        role="img"
        aria-label="Пример: перенос медиатеки из Яндекс Музыки выполнен на 94%. В единой медиатеке 1 284 трека, 346 любимых и 28 плейлистов."
      >
        <div className="transfer-story" aria-hidden>
          <div className="transfer-story-top">
            <span className="transfer-glyph"><Music2 size={20} /></span>
            <span>Перенос</span>
            <span className="transfer-live"><i /> идёт перенос</span>
          </div>
          <p className="transfer-title">Твоя музыка.<br />Теперь здесь.</p>
          <div className="transfer-provider-row">
            <span className="is-active"><i className="provider-yandex" /> Яндекс</span>
            <span><i className="provider-spotify" /> Spotify</span>
            <span><i className="provider-vk" /> VK</span>
          </div>
          <div className="transfer-progress-copy">
            <span>Раскладываем коллекцию</span><b>94%</b>
          </div>
          <div className="transfer-progress"><i /></div>
          <ul className="transfer-checks">
            <li><Check size={15} /> Любимые треки</li>
            <li><Check size={15} /> Плейлисты и порядок треков</li>
            <li><Check size={15} /> Обложки, альбомы и исполнители</li>
          </ul>
        </div>

        <div className="library-story" aria-hidden>
          <div className="library-story-head">
            <div>
              <span className="library-kicker">Единая медиатека</span>
              <p className="library-count">1 284 трека.<br />Один дом.</p>
            </div>
            <div className="library-story-metric"><Heart size={16} /><b>346</b><small>любимых</small></div>
            <div className="library-story-metric"><Music2 size={16} /><b>28</b><small>плейлистов</small></div>
          </div>
          <p className="library-kicker library-shelf-label">Недавно добавлено</p>
          <div className="library-track-grid">
            {tracks.map((track) => (
              <div key={track.title}>
                <div className={`library-cover ${track.tone}`}><span>{track.initials}</span></div>
                <b>{track.title}</b><small>{track.artist}</small>
              </div>
            ))}
          </div>
          <div className="library-bottom-row">
            <span><Album size={16} /> 176 альбомов</span>
            <span>92 исполнителя</span>
          </div>
        </div>
      </div>
      <a className="panel-link" href="#download">Перенести свою медиатеку <ArrowRight size={17} aria-hidden /></a>
    </div>
  );
}
