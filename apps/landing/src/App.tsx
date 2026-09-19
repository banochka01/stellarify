import { useLayoutEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import {
  ArrowDown,
  ArrowRight,
  Apple,
  Combine,
  Download,
  FileText,
  Heart,
  Network,
  Layers3,
  Link2,
  ListMusic,
  Plus,
  Radio,
  Search,
  ShieldCheck,
  Smartphone,
  Users,
  Volume2
} from "lucide-react";
import { DemoSandbox } from "./components/DemoSandbox";
import { HeroStage } from "./components/HeroStage";
import { LyricsCinema } from "./components/LyricsCinema";
import { LibraryCinema } from "./components/LibraryCinema";
import { QueueCinema } from "./components/QueueCinema";
import { RoomsCinema } from "./components/RoomsCinema";

gsap.registerPlugin(ScrollTrigger);

const downloads = {
  windows: "/downloads/windows",
  windowsPortable: "/downloads/windows-portable",
  android: "/downloads/android",
  ios: "/downloads/ios"
};

function App() {
  const root = useRef<HTMLDivElement>(null);

  useLayoutEffect(() => {
    const context = gsap.context(() => {
      const media = gsap.matchMedia();
      media.add(
        {
          reduce: "(prefers-reduced-motion: reduce)",
          desktop: "(min-width: 900px)"
        },
        ({ conditions }) => {
          const { reduce } = conditions as {
            reduce: boolean;
            desktop: boolean;
          };

          if (reduce) {
            gsap.set("[data-reveal]", { autoAlpha: 1, y: 0 });
            return;
          }

          gsap.from(".hero-copy > *", {
            autoAlpha: 0,
            y: 38,
            duration: 0.85,
            stagger: 0.09,
            ease: "power3.out"
          });
          gsap.from(".stage-card", {
            autoAlpha: 0,
            y: 56,
            duration: 1.15,
            delay: 0.25,
            ease: "power3.out"
          });
          gsap.to(".stage-card", {
            yPercent: -5,
            ease: "none",
            scrollTrigger: {
              trigger: ".hero",
              start: "top top",
              end: "bottom top",
              scrub: 1.1
            }
          });

          ScrollTrigger.batch("[data-reveal]", {
            start: "top 84%",
            once: true,
            onEnter: (elements) =>
              gsap.fromTo(
                elements,
                { autoAlpha: 0, y: 58 },
                {
                  autoAlpha: 1,
                  y: 0,
                  duration: 0.9,
                  stagger: 0.12,
                  ease: "power3.out",
                  overwrite: true
                }
              )
          });
        }
      );

      return () => media.revert();
    }, root);

    return () => context.revert();
  }, []);

  return (
    <div ref={root} className="site-shell">
      <header className="site-header">
        <a className="brand" href="#top" aria-label="Resonance — наверх">
          <span className="brand-mark"><Volume2 size={19} /></span>
          <span>Resonance</span>
        </a>
        <nav aria-label="Основная навигация">
          <a href="#features">Возможности</a>
          <a href="#graph">Music Graph</a>
          <a href="#rooms">Комнаты</a>
          <a href="#demo">Демо</a>
          <a href="#free">Бесплатно</a>
          <a href="#privacy">Приватность</a>
          <a href="#faq">FAQ</a>
        </nav>
        <a className="header-download" href={downloads.windows}>
          <Download size={16} /> Скачать
        </a>
      </header>

      <main>
        <section className="hero" id="top">
          <div className="hero-copy">
            <p className="eyebrow">Музыка без переключений</p>
            <h1>Музыка<br /><em>живёт</em><br />здесь.</h1>
            <p className="hero-lead">
              Один трек, все его источники и связи. Music Graph очищает
              медиатеку от дублей, а Wave 2.0 продолжает путь по музыке.
              Все возможности Resonance доступны бесплатно.
            </p>
            <div className="provider-chips">
              <span className="provider-chip"><img src="/assets/logos/yandex-music.svg" alt="" width={16} height={16} />Яндекс Музыка</span>
              <span className="provider-chip"><img src="/assets/logos/soundcloud.svg" alt="" width={16} height={16} />SoundCloud</span>
              <span className="provider-chip"><img src="/assets/logos/youtube.svg" alt="" width={16} height={16} />YouTube</span>
              <span className="provider-chip"><img src="/assets/logos/spotify.svg" alt="" width={16} height={16} />Spotify</span>
              <span className="provider-chip"><img src="/assets/logos/vk.svg" alt="" width={16} height={16} />VK Музыка</span>
            </div>
            <div className="hero-actions">
              <a className="button button-primary" href={downloads.windows}>
                <Download size={18} /> Windows Setup EXE
              </a>
              <a className="button button-secondary" href={downloads.windowsPortable}>
                <Download size={18} /> Portable ZIP
              </a>
              <a className="button button-secondary" href={downloads.android}>
                <Smartphone size={18} /> Версия для Android
              </a>
              <a className="button button-secondary" href={downloads.ios}>
                <Apple size={18} /> Unsigned IPA
              </a>
            </div>
            <p className="release-note">Resonance 3.4.0 · YouTube Music в настройках · Больше видео-превью · Стабильная обложка · Все любимые одной кнопкой</p>
          </div>
          <div className="hero-visual">
            <HeroStage />
          </div>
          <div className="stage-marquee" aria-hidden>
            <div className="stage-marquee-track">
              {[0, 1].map((copy) => (
                <span className="stage-marquee-run" key={copy}>
                  <b>Alpha House</b><i>Knucks &amp; Venna</i>
                  <b>Большие бабки</b><i>OG Buda &amp; Scally Milano</i>
                  <b>Подруга Подруг</b><i>SLIME &amp; FACE</i>
                  <b>Выходной</b><i>MONATIK</i>
                </span>
              ))}
            </div>
          </div>
          <a className="scroll-cue" href="#features" aria-label="К возможностям">
            <ArrowDown size={26} />
          </a>
        </section>

        <section className="search-section" id="features">
          <div className="section-heading" data-reveal>
            <div>
              <p className="eyebrow">Поиск без границ</p>
              <h2>Один поиск —<br /><em>разные</em><br />источники.</h2>
            </div>
            <p>
              Resonance ищет музыку в SoundCloud, Яндекс Музыке, Spotify и
              VK Музыке, объединяет результаты и воспроизводит их только в
              собственном плеере.
            </p>
          </div>

          <QueueCinema />

          <div className="feature-row">
            <article data-reveal>
              <span><Search size={24} /></span>
              <h3>Единый поиск</h3>
              <p>Один запрос — результаты из всех подключённых каталогов.</p>
            </article>
            <article data-reveal>
              <span><FileText size={24} /></span>
              <h3>Синхронные тексты</h3>
              <p>Активная строка следует за музыкой, а обычный текст остаётся доступным без таймкодов.</p>
            </article>
            <article data-reveal>
              <span><Heart size={24} /></span>
              <h3>Wave понимает контекст</h3>
              <p>«Спокойнее», «больше нового», «без этого артиста» — очередь перестраивается без выдуманных треков.</p>
            </article>
          </div>
        </section>

        <LibraryCinema />

        <section className="graph-section" id="graph">
          <div className="section-heading" data-reveal>
            <div>
              <p className="eyebrow">Resonance 3.0</p>
              <h2>Один трек.<br /><em>Все</em> его связи.</h2>
            </div>
            <p>
              Music Graph узнаёт одну композицию в разных сервисах, сохраняет
              все доступные источники и связывает музыку по артисту и альбому.
            </p>
          </div>
          <div className="graph-showcase" data-reveal>
            <div className="graph-orbit" aria-label="Пример музыкального графа">
              <span className="graph-line graph-line-a" />
              <span className="graph-line graph-line-b" />
              <span className="graph-line graph-line-c" />
              <button className="graph-node graph-node-main" type="button">
                <Network size={28} /><b>Nightcall</b><small>2 источника</small>
              </button>
              <button className="graph-node graph-node-a" type="button"><span>Kavinsky</span></button>
              <button className="graph-node graph-node-b" type="button"><span>OutRun</span></button>
              <button className="graph-node graph-node-c" type="button"><span>Odd Look</span></button>
            </div>
            <div className="graph-copy">
              <article><Combine size={22} /><div><h3>Без дублей</h3><p>Яндекс, Spotify и VK становятся источниками одной записи, а не тремя одинаковыми треками.</p></div></article>
              <article><Network size={22} /><div><h3>Живое окружение</h3><p>Переходи от композиции к альбому и другим работам артиста прямо на карте.</p></div></article>
              <article><ShieldCheck size={22} /><div><h3>Безопасное объединение</h3><p>Совпадение требует одинаковых названия, артиста и близкой длительности. Live и remix остаются отдельно.</p></div></article>
            </div>
          </div>
        </section>

        <LyricsCinema />

        <section className="rooms-section" id="rooms">
          <div className="section-heading" data-reveal>
            <div>
              <p className="eyebrow">Слушать вместе</p>
              <h2>Одна очередь.<br /><em>Все</em> синхронно.</h2>
            </div>
            <p>
              Комната синхронизирует воспроизведение у каждого участника:
              пауза, перемотка и живая очередь общие. Слушайте одновременно,
              где бы вы ни находились.
            </p>
          </div>

          <RoomsCinema />

          <div className="rooms-after">
            <div className="feature-row feature-row-stack">
              <article data-reveal>
                <span><Radio size={24} /></span>
                <h3>Живая синхронизация</h3>
                <p>Пауза, перемотка и смена трека мгновенно применяются у всех участников комнаты.</p>
              </article>
              <article data-reveal>
                <span><Link2 size={24} /></span>
                <h3>Приглашение ссылкой</h3>
                <p>Создатель комнаты делится ссылкой — друзья присоединяются в один клик.</p>
              </article>
              <article data-reveal>
                <span><ListMusic size={24} /></span>
                <h3>Общая очередь</h3>
                <p>Очередь одна на всех: добавляйте треки из любого подключённого источника.</p>
              </article>
            </div>
            <p className="rooms-note" data-reveal>Комнаты доступны бесплатно всем пользователям с аккаунтом Resonance.</p>
          </div>
        </section>

        <DemoSandbox />

        <section className="free-section" id="free">
          <div className="free-heading" data-reveal>
            <div>
              <p className="eyebrow">Проект получил финансирование</p>
              <h2>Все возможности.<br /><em>Бесплатно.</em></h2>
            </div>
            <p>
              У Resonance больше нет платных уровней, пробного периода и
              промокодов. Скачивай приложение и используй все функции без оплаты.
            </p>
          </div>
          <div className="free-grid">
            <article className="free-card" data-reveal>
              <Volume2 size={24} />
              <h3>Полный плеер</h3>
              <p>Все поддерживаемые источники, единый поиск, импорт, тексты и Music Graph без ограничений Resonance.</p>
            </article>
            <article className="free-card free-card-accent" data-reveal>
              <Heart size={24} />
              <h3>Wave без уровней</h3>
              <p>Персональные подборки, музыкальная память и управление очередью обычным языком доступны всем.</p>
            </article>
            <article className="free-card" data-reveal>
              <Users size={24} />
              <h3>Комнаты для всех</h3>
              <p>Создавай комнаты, приглашай друзей и слушай синхронно. Для общей сессии нужен только бесплатный аккаунт.</p>
            </article>
          </div>
          <p className="free-note" data-reveal>Некоторые музыкальные сервисы могут требовать собственный аккаунт, токен или подписку по правилам самого источника. Resonance за доступ к своим функциям плату не берёт.</p>
        </section>

        <section className="interface-section" id="interface">
          <div className="interface-copy" data-reveal>
            <p className="eyebrow">Один выразительный плеер</p>
            <h2>Не ещё один<br />клон стриминга.</h2>
            <p>
              Один нативный плеер Resonance для всех разрешённых источников:
              Flow-переходы, выравнивание громкости, живая очередь, lyrics и
              стабильное адаптивное управление на каждом экране.
            </p>
            <a href={downloads.windows}>Попробовать Resonance <ArrowRight size={17} /></a>
          </div>
          <figure className="app-frame" data-reveal>
            <img src="/assets/resonance-app-editorial.png" alt="Интерфейс Resonance: поиск и плеер" />
          </figure>
        </section>

        <section className="privacy-section" id="privacy">
          <div data-reveal>
            <ShieldCheck size={34} />
            <p className="eyebrow">Приватность по архитектуре</p>
            <h2>Прокси остаётся<br />на сервере.</h2>
          </div>
          <div className="privacy-copy" data-reveal>
            <p>
              Клиент передаёт только переключатель «использовать прокси».
              Адрес, логин и пароль не попадают в приложение и не выдаются API.
            </p>
            <p>
              Токены сервисов хранятся в защищённом хранилище устройства и
              отправляются только для выполнения запроса.
            </p>
          </div>
        </section>

        <section className="steps-section" id="start">
          <div className="steps-heading" data-reveal>
            <p className="eyebrow">Как начать</p>
            <h2>Три шага<br /><em>до музыки.</em></h2>
          </div>
          <ol className="steps-grid">
            <li data-reveal>
              <span className="step-index">01</span>
              <h3>Установи Resonance</h3>
              <p>Setup EXE или Portable ZIP для Windows, APK для Android, IPA для iOS.</p>
            </li>
            <li data-reveal>
              <span className="step-index">02</span>
              <h3>Подключи источники</h3>
              <p>Войди в SoundCloud, Яндекс Музыку, Spotify или VK — их каталоги появятся в едином поиске.</p>
            </li>
            <li data-reveal>
              <span className="step-index">03</span>
              <h3>Слушай</h3>
              <p>Живая очередь, синхронные тексты, комнаты и Wave — в одном нативном плеере.</p>
            </li>
          </ol>
        </section>

        <section className="faq-section" id="faq">
          <div className="faq-layout">
            <div className="faq-heading" data-reveal>
              <p className="eyebrow">Вопросы и ответы</p>
              <h2>Коротко<br /><em>о главном.</em></h2>
            </div>
            <div className="faq-list">
              <details data-reveal>
                <summary>Нужна ли подписка на источники — SoundCloud, Яндекс, Spotify, VK? <Plus size={18} /></summary>
                <p>Сам Resonance полностью бесплатный. Доступ к каталогу и полным трекам зависит от правил выбранного источника: где-то достаточно серверного подключения Resonance, а где-то нужен твой аккаунт, токен или подписка самого музыкального сервиса.</p>
              </details>
              <details data-reveal>
                <summary>Resonance действительно бесплатный? <Plus size={18} /></summary>
                <p>Да. Проект получил финансирование, поэтому в Resonance нет платных уровней, пробного срока, промокодов и ограничений функций по оплате.</p>
              </details>
              <details data-reveal>
                <summary>Что умеет Wave? <Plus size={18} /></summary>
                <p>Wave собирает очередь по описанию настроения и перестраивает её на лету: «спокойнее», «больше нового», «без этого артиста». Только реальные треки из подключённых каталогов — без выдуманных названий.</p>
              </details>
              <details data-reveal>
                <summary>Как работают комнаты? <Plus size={18} /></summary>
                <p>Создатель комнаты получает ссылку-приглашение, а воспроизведение синхронизировано у всех участников. Создание и вход доступны бесплатно после входа в аккаунт Resonance.</p>
              </details>
              <details data-reveal>
                <summary>Что с приватностью? <Plus size={18} /></summary>
                <p>Прокси остаётся на сервере: клиент передаёт только переключатель его использования. Токены сервисов хранятся в защищённом хранилище устройства и отправляются только для выполнения запроса.</p>
              </details>
            </div>
          </div>
        </section>

        <section className="final-cta" data-reveal>
          <Layers3 size={32} />
          <h2>Твои сервисы.<br /><em>Один Resonance.</em></h2>
          <div className="hero-actions">
            <a className="button button-primary" href={downloads.windows}>Скачать Setup EXE</a>
            <a className="button button-secondary" href={downloads.windowsPortable}>Скачать Portable ZIP</a>
            <a className="button button-secondary" href={downloads.android}>Скачать APK</a>
            <a className="button button-secondary" href={downloads.ios}>Скачать unsigned IPA</a>
          </div>
        </section>
      </main>

      <footer>
        <a className="brand" href="#top"><span className="brand-mark"><Volume2 size={17} /></span>Resonance</a>
        <nav className="footer-nav" aria-label="Разделы лендинга">
          <a href="#features">Возможности</a>
          <a href="#rooms">Комнаты</a>
          <a href="#demo">Демо</a>
          <a href="#free">Бесплатно</a>
          <a href="#privacy">Приватность</a>
          <a href="#faq">FAQ</a>
        </nav>
        <span>© 2026 WebCord</span>
        <span>Windows · Android · iOS</span>
      </footer>
    </div>
  );
}

export default App;
