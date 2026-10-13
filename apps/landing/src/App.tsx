import { useEffect, useLayoutEffect, useRef, useState } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import {
  ArrowDown,
  ArrowRight,
  Apple,
  BookOpen,
  Car,
  Cast,
  Combine,
  Disc3,
  FlaskConical,
  Laptop,
  Moon,
  Mic2,
  Monitor,
  Sparkles,
  Sun,
  Trash2,
  Tv,
  UserPlus,
  Watch,
  Waves,
  Download,
  FileText,
  Heart,
  KeyRound,
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
import { GraphHero } from "./components/GraphHero";
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

type Theme = "dark" | "light";

function readTheme(): Theme {
  try {
    const saved = localStorage.getItem("resonance-theme");
    if (saved === "light" || saved === "dark") return saved;
  } catch {
    /* storage unavailable */
  }
  return window.matchMedia?.("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

function useTheme() {
  const [theme, setTheme] = useState<Theme>(readTheme);
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    document.querySelector('meta[name="theme-color"]')?.setAttribute("content", theme === "light" ? "#f6f3ec" : "#070706");
    window.dispatchEvent(new Event("resonance-theme"));
  }, [theme]);
  const toggle = () => {
    const next: Theme = theme === "dark" ? "light" : "dark";
    try { localStorage.setItem("resonance-theme", next); } catch { /* ignore */ }
    setTheme(next);
  };
  return { theme, toggle };
}

const features5 = [
  { id: "graph", icon: Network, title: "Music Graph", text: "Каждый трек — узел графа: источники, артисты, альбомы, похожие записи и связи между ними. Переходи по музыке, как по карте." },
  { id: "friends", icon: UserPlus, title: "Друзья и совместимость", text: "Добавляй друзей и смотри процент музыкального совпадения: общие артисты, жанры и треки, которые стоит послушать вместе." },
  { id: "blend", icon: Combine, title: "Blend", text: "Общий плейлист для двоих или компании, который собирается из вкусов всех участников и обновляется сам." },
  { id: "dj", icon: Disc3, title: "DJ-комнаты", text: "Ведущий управляет очередью, слушатели предлагают треки и голосуют. Синхронное воспроизведение у всех." },
  { id: "sound", icon: Waves, title: "Чистый звук", text: "Нормализация громкости, gapless-переходы без пауз и lossless там, где источник его отдаёт." },
  { id: "cast", icon: Cast, title: "ТВ и колонки", text: "Трансляция на телевизоры и умные колонки в локальной сети — очередь остаётся в телефоне." },
  { id: "car", icon: Car, title: "Авто, часы и ТВ", text: "Android Auto, CarPlay, Wear OS и Android TV: управление и обложки там, где ты сейчас." },
  { id: "desktop", icon: Laptop, title: "macOS и Linux · скоро", text: "Сборки для macOS и Linux скоро появятся рядом с Windows — с тем же аккаунтом и медиатекой." },
  { id: "artists", icon: Mic2, title: "Артисты и сет-листы", text: "Обновлённые страницы артистов: дискография, связи в графе и сет-листы концертов." },
  { id: "cleanup", icon: Trash2, title: "Чистка библиотеки", text: "Поиск дублей, недоступных треков и пустых плейлистов. Всё показывается заранее, ничего не удаляется без подтверждения." },
  { id: "beta", icon: FlaskConical, title: "Бета-канал", text: "Получай новые возможности раньше всех и помогай найти ошибки. Переключение в настройках, вернуться можно в любой момент." }
];

const platforms = [
  { icon: Monitor, name: "Windows", note: "Setup EXE · x64", href: downloads.windows, cta: "Скачать EXE" },
  { icon: Monitor, name: "Windows Portable", note: "ZIP без установки", href: downloads.windowsPortable, cta: "Скачать ZIP" },
  { icon: Smartphone, name: "Android", note: "APK · Android Auto, Wear OS, TV", href: downloads.android, cta: "Скачать APK" },
  { icon: Apple, name: "iOS", note: "Unsigned IPA · нужна своя подпись", href: downloads.ios, cta: "Скачать IPA" },
  { icon: Laptop, name: "macOS", note: "Сборка готовится", href: null, cta: "Скоро" },
  { icon: Laptop, name: "Linux", note: "Сборка готовится", href: null, cta: "Скоро" }
];

function App() {
  const root = useRef<HTMLDivElement>(null);
  const { theme, toggle } = useTheme();

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
          gsap.from(".graph-hero", {
            autoAlpha: 0,
            scale: 0.96,
            duration: 1.15,
            delay: 0.2,
            ease: "power3.out"
          });
          gsap.to(".graph-hero", {
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
      <a className="skip-link" href="#main">К содержимому</a>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="Resonance — наверх">
          <span className="brand-mark"><img src="/assets/resonance-mark.png" alt="" width={24} height={24} /></span>
          <span>Resonance</span>
        </a>
        <nav aria-label="Основная навигация">
          <a href="#new">Что нового</a>
          <a href="#features">Поиск</a>
          <a href="#rooms">Комнаты</a>
          <a href="#download">Скачать</a>
          <a href="#faq">FAQ</a>
        </nav>
        <div className="header-actions">
          <button
            type="button"
            className="theme-toggle"
            onClick={toggle}
            aria-label={theme === "dark" ? "Включить светлую тему" : "Включить тёмную тему"}
          >
            {theme === "dark" ? <Sun size={18} /> : <Moon size={18} />}
          </button>
          <a className="header-download" href="#download">
            <Download size={16} /> Скачать
          </a>
        </div>
      </header>

      <main id="main">
        <section className="hero hero-graph" id="top">
          <div className="hero-copy">
            <p className="eyebrow"><Sparkles size={13} aria-hidden /> Resonance 5.0 · Graph</p>
            <h1>Музыка —<br />это <em>связи</em>.</h1>
            <p className="hero-lead">
              Resonance 5.0 превращает медиатеку в живой граф: треки, артисты,
              друзья и общие вкусы. Слушай вместе в DJ-комнатах, собирай Blend
              и включай музыку на ТВ, в машине и на часах. Бесплатно.
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
                <Download size={18} /> Скачать для Windows
              </a>
              <a className="button button-secondary" href="#download">
                Все платформы <ArrowRight size={17} />
              </a>
            </div>
            <p className="release-note">Windows · Android · iOS сейчас, macOS и Linux — скоро.</p>
          </div>
          <div className="hero-visual">
            <GraphHero />
          </div>
          <a className="scroll-cue" href="#new" aria-label="К новым возможностям">
            <ArrowDown size={26} />
          </a>
        </section>

        <section className="new-section" id="new" aria-labelledby="new-title">
          <div className="section-heading" data-reveal>
            <div>
              <p className="eyebrow">Что нового в 5.0</p>
              <h2 id="new-title">Всё вокруг<br /><em>одного графа.</em></h2>
            </div>
            <p>
              Пятая версия связывает твою музыку, друзей и устройства. Каждая
              возможность ниже доступна бесплатно с аккаунтом Resonance.
            </p>
          </div>
          <ul className="new-grid">
            {features5.map(({ id, icon: Icon, title, text }) => (
              <li key={id} id={id} className="new-card" data-reveal>
                <span className="new-icon"><Icon size={22} aria-hidden /></span>
                <h3>{title}</h3>
                <p>{text}</p>
              </li>
            ))}
          </ul>
          <ul className="devices-strip" data-reveal aria-label="Поддерживаемые устройства">
            <li><Monitor size={18} aria-hidden />Windows</li>
            <li><Laptop size={18} aria-hidden />macOS</li>
            <li><Laptop size={18} aria-hidden />Linux</li>
            <li><Smartphone size={18} aria-hidden />Android</li>
            <li><Apple size={18} aria-hidden />iOS</li>
            <li><Car size={18} aria-hidden />Android Auto · CarPlay</li>
            <li><Watch size={18} aria-hidden />Wear OS</li>
            <li><Tv size={18} aria-hidden />Android TV</li>
          </ul>
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

        <section className="knowledge-section" id="knowledge">
          <div className="knowledge-heading" data-reveal>
            <div>
              <p className="eyebrow">База знаний</p>
              <h2>Подключение<br /><em>без догадок.</em></h2>
            </div>
            <p>
              Токены — это пароли приложений. Не отправляйте их в чаты и не
              сохраняйте в обычных заметках. Resonance хранит пользовательские
              данные подключения в защищённом хранилище устройства.
            </p>
          </div>
          <div className="knowledge-grid">
            <article data-reveal>
              <span className="knowledge-icon spotify"><KeyRound size={22} /></span>
              <p className="plan-kicker">Spotify · рекомендуемый способ</p>
              <h3>Войти официально</h3>
              <ol>
                <li>Откройте «Настройки → Подключения → Spotify».</li>
                <li>Нажмите «Войти через Spotify» и подтвердите доступ к медиатеке и плейлистам.</li>
                <li>Вернитесь в Resonance: приложение проверит вход и сохранит refresh-credential на устройстве.</li>
              </ol>
              <p className="knowledge-note">Ручной access token больше не нужен. Если вход не открывается, администратор сервера должен добавить точный HTTPS callback в Spotify Dashboard.</p>
              <a href="https://developer.spotify.com/documentation/web-api/concepts/authorization" target="_blank" rel="noreferrer">Официальная документация Spotify <ArrowRight size={15} /></a>
            </article>
            <article data-reveal>
              <span className="knowledge-icon"><KeyRound size={22} /></span>
              <p className="plan-kicker">Яндекс Музыка</p>
              <h3>OAuth приложения</h3>
              <ol>
                <li>Создайте OAuth-приложение в Яндекс ID и разрешите доступ только к нужным данным.</li>
                <li>Пройдите авторизацию владельцем музыкальной библиотеки и получите OAuth-токен через настроенный redirect URI.</li>
                <li>Вставьте токен в Resonance и дождитесь сообщения о проверке.</li>
              </ol>
              <p className="knowledge-note">Не копируйте cookie браузера и не используйте сайты-«генераторы токенов».</p>
              <a href="https://yandex.ru/dev/id/doc/ru/concepts/ya-oauth-intro" target="_blank" rel="noreferrer">Документация Яндекс OAuth <ArrowRight size={15} /></a>
            </article>
            <article data-reveal>
              <span className="knowledge-icon"><KeyRound size={22} /></span>
              <p className="plan-kicker">SoundCloud</p>
              <h3>Client ID или OAuth</h3>
              <ol>
                <li>Зарегистрируйте приложение в SoundCloud for Developers.</li>
                <li>Возьмите Client ID в настройках приложения либо выполните OAuth flow для личного access token.</li>
                <li>Вставьте значение в Resonance; cookie <code>oauth_token</code> не подходит.</li>
              </ol>
              <p className="knowledge-note">Если серверный Client ID уже настроен, этот шаг можно пропустить.</p>
              <a href="https://developers.soundcloud.com/docs/api/guide" target="_blank" rel="noreferrer">SoundCloud API Guide <ArrowRight size={15} /></a>
            </article>
            <article data-reveal>
              <span className="knowledge-icon"><KeyRound size={22} /></span>
              <p className="plan-kicker">VK Музыка</p>
              <h3>Токен с audio-доступом</h3>
              <ol>
                <li>Создайте приложение в VK для разработчиков и настройте доверенный redirect URI.</li>
                <li>Запросите пользовательский OAuth token только с необходимыми разрешениями.</li>
                <li>Проверьте токен в Resonance. Если VK не выдал права audio, источник останется недоступен.</li>
              </ol>
              <p className="knowledge-note">Доступ к audio API ограничивается политикой VK и может быть недоступен обычным приложениям.</p>
              <a href="https://dev.vk.com/ru/api/access-token/getting-started" target="_blank" rel="noreferrer">VK Access Token <ArrowRight size={15} /></a>
            </article>
          </div>
          <div className="knowledge-admin" data-reveal>
            <BookOpen size={24} />
            <div><h3>Для администратора сервера</h3><p>Видеоисточники включаются переменными <code>YOUTUBE_API_KEY</code>, <code>VIMEO_ACCESS_TOKEN</code>, <code>AUDIODB_API_KEY</code> и <code>PEXELS_API_KEY</code>. Spotify требует <code>SPOTIFY_CLIENT_ID</code>, а callback должен точно совпадать с <code>https://music.webcordes.ru/api/v1/auth/spotify/callback</code>.</p></div>
          </div>
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

        <section className="download-section" id="download" aria-labelledby="download-title">
          <div className="section-heading" data-reveal>
            <div>
              <p className="eyebrow">Загрузки</p>
              <h2 id="download-title">Твои сервисы.<br /><em>Один Resonance.</em></h2>
            </div>
            <p>
              Ссылки всегда ведут на актуальный релиз. iOS-сборка не подписана —
              её нужно подписать своим сертификатом.
            </p>
          </div>
          <ul className="platform-grid">
            {platforms.map(({ icon: Icon, name, note, href, cta }) => (
              <li key={name} className={href ? "platform-card" : "platform-card platform-soon"} data-reveal>
                <Icon size={24} aria-hidden />
                <div>
                  <h3>{name}</h3>
                  <p>{note}</p>
                </div>
                {href ? (
                  <a className="button button-primary" href={href}><Download size={16} aria-hidden /> {cta}</a>
                ) : (
                  <span className="soon-badge">{cta}</span>
                )}
              </li>
            ))}
          </ul>
        </section>
      </main>

      <footer>
        <a className="brand" href="#top" aria-label="Resonance — наверх"><span className="brand-mark"><img src="/assets/resonance-mark.png" alt="" width={22} height={22} /></span>Resonance</a>
        <nav className="footer-nav" aria-label="Разделы лендинга">
          <a href="#new">Что нового</a>
          <a href="#features">Поиск</a>
          <a href="#rooms">Комнаты</a>
          <a href="#demo">Демо</a>
          <a href="#download">Скачать</a>
          <a href="#free">Бесплатно</a>
          <a href="#privacy">Приватность</a>
          <a href="#knowledge">База знаний</a>
          <a href="#faq">FAQ</a>
        </nav>
        <span>© 2026 WebCord</span>
        <span>Windows · Android · iOS · macOS и Linux скоро</span>
      </footer>
    </div>
  );
}

export default App;
