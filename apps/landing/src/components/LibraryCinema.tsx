import { Album, ArrowRight, Check, Heart, Music2, Sparkles } from "lucide-react";

const tracks = [
  { title: "Tadow", artist: "Masego, FKJ", tone: "ember", initials: "MF" },
  { title: "Nightcall", artist: "Kavinsky", tone: "violet", initials: "K" },
  { title: "After Dark", artist: "Mr.Kitty", tone: "crimson", initials: "M" },
  { title: "Midnight City", artist: "M83", tone: "blue", initials: "M" }
];

export function LibraryCinema() {
  return (
    <section className="library-section" id="library">
      <div className="section-heading" data-reveal>
        <div>
          <p className="eyebrow">Resonance Library</p>
          <h2>Забери всё.<br /><em>Музыка</em><br />останется.</h2>
        </div>
        <p>
          Один перенос забирает любимые треки и плейлисты из Яндекс Музыки,
          Spotify или VK. Без ручного копирования и без потери оригиналов.
        </p>
      </div>

      <div className="library-cinema" data-reveal>
        <div className="transfer-story">
          <div className="transfer-story-top">
            <span className="transfer-glyph"><Sparkles size={20} /></span>
            <span>RESONANCE TRANSFER</span>
            <span className="transfer-live"><i /> идёт перенос</span>
          </div>
          <h3>Твоя музыка.<br />Теперь здесь.</h3>
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

        <div className="library-story">
          <div className="library-story-head">
            <div>
              <span>ЕДИНАЯ МЕДИАТЕКА</span>
              <h3>1 284 трека.<br />Один дом.</h3>
            </div>
            <div className="library-story-metric"><Heart size={16} /><b>346</b><small>любимых</small></div>
            <div className="library-story-metric"><Music2 size={16} /><b>28</b><small>плейлистов</small></div>
          </div>
          <p className="library-shelf-label"><Sparkles size={15} /> Недавно добавлено</p>
          <div className="library-track-grid">
            {tracks.map((track) => (
              <article key={track.title}>
                <div className={`library-cover ${track.tone}`}><span>{track.initials}</span></div>
                <b>{track.title}</b><small>{track.artist}</small>
              </article>
            ))}
          </div>
          <div className="library-bottom-row">
            <span><Album size={16} /> 176 альбомов</span>
            <span>92 исполнителя</span>
            <a href="#top">Открыть Resonance <ArrowRight size={15} /></a>
          </div>
        </div>
      </div>
    </section>
  );
}
