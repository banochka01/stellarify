import { Suspense, lazy, useCallback, useEffect, useRef, useState, type KeyboardEvent, type ReactNode } from "react";
import {
  ArrowDown,
  ArrowRight,
  Apple,
  BookOpen,
  Car,
  Cast,
  ChevronRight,
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
  Heart,
  KeyRound,
  Network,
  Plus,
  ShieldCheck,
  Smartphone,
  Users,
  Volume2
} from "lucide-react";
import { GraphHero } from "./components/GraphHero";
import { Modal } from "./components/Modal";

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
  { id: "graph", icon: Network, title: "Music Graph", teaser: "Музыка как карта связей.", text: "Каждый трек — узел графа: источники, артисты, альбомы, похожие записи и связи между ними. Переходи по музыке, как по карте." },
  { id: "friends", icon: UserPlus, title: "Друзья и совместимость", teaser: "Процент музыкального совпадения.", text: "Добавляй друзей и смотри процент музыкального совпадения: общие артисты, жанры и треки, которые стоит послушать вместе." },
  { id: "blend", icon: Combine, title: "Blend", teaser: "Общий плейлист из вкусов всех.", text: "Общий плейлист для двоих или компании, который собирается из вкусов всех участников и обновляется сам." },
  { id: "dj", icon: Disc3, title: "DJ-комнаты", teaser: "Ведущий, очередь и предложения.", text: "Ведущий управляет очередью, слушатели предлагают треки и голосуют. Синхронное воспроизведение у всех." },
  { id: "sound", icon: Waves, title: "Чистый звук", teaser: "Нормализация, gapless, lossless.", text: "Нормализация громкости, gapless-переходы без пауз и lossless там, где источник его отдаёт." },
  { id: "cast", icon: Cast, title: "ТВ и колонки", teaser: "Трансляция в локальной сети.", text: "Трансляция на телевизоры и умные колонки в локальной сети — очередь остаётся в телефоне." },
  { id: "car", icon: Car, title: "Авто, часы и ТВ", teaser: "Android Auto, CarPlay, Wear OS.", text: "Android Auto, CarPlay, Wear OS и Android TV: управление и обложки там, где ты сейчас." },
  { id: "desktop", icon: Laptop, title: "macOS и Linux · скоро", teaser: "Новые десктопные сборки.", text: "Сборки для macOS и Linux скоро появятся рядом с Windows — с тем же аккаунтом и медиатекой." },
  { id: "artists", icon: Mic2, title: "Страницы артистов", teaser: "Дискография и связи в графе.", text: "Обновлённые страницы артистов: дискография, популярные треки и связи с другими артистами в графе." },
  { id: "cleanup", icon: Trash2, title: "Чистка библиотеки", teaser: "Дубли и пустые плейлисты.", text: "Поиск дублей, недоступных треков и пустых плейлистов. Всё показывается заранее, ничего не удаляется без подтверждения." },
  { id: "beta", icon: FlaskConical, title: "Бета-канал", teaser: "Новое — раньше всех.", text: "Получай новые возможности раньше всех и помогай найти ошибки. Переключение в настройках, вернуться можно в любой момент." }
];

const platforms = [
  { icon: Monitor, name: "Windows", note: "Setup EXE · x64", href: downloads.windows, cta: "Скачать EXE" },
  { icon: Monitor, name: "Windows Portable", note: "ZIP без установки", href: downloads.windowsPortable, cta: "Скачать ZIP" },
  { icon: Smartphone, name: "Android", note: "APK · Android Auto, Wear OS, TV", href: downloads.android, cta: "Скачать APK" },
  { icon: Apple, name: "iOS", note: "Unsigned IPA · нужна своя подпись", href: downloads.ios, cta: "Скачать IPA" },
  { icon: Laptop, name: "macOS", note: "Сборка готовится", href: null, cta: "Скоро" },
  { icon: Laptop, name: "Linux", note: "Сборка готовится", href: null, cta: "Скоро" }
];

/* Heavy demo components are split into chunks and fetched only when their tab opens. */
const tabs = [
  { key: "search", label: "Поиск", load: lazy(() => import("./panels/SearchPanel")) },
  { key: "library", label: "Медиатека", load: lazy(() => import("./components/LibraryCinema").then((m) => ({ default: m.LibraryCinema }))) },
  { key: "rooms", label: "Комнаты", load: lazy(() => import("./panels/RoomsPanel")) },
  { key: "lyrics", label: "Тексты и интерфейс", load: lazy(() => import("./panels/LyricsPanel")) },
  { key: "demo", label: "Демо Wave", load: lazy(() => import("./components/DemoSandbox").then((m) => ({ default: m.DemoSandbox }))) }
] as const;

function scrollTo(id: string) {
  const reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  document.getElementById(id)?.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" });
}

type TabKey = (typeof tabs)[number]["key"];
type InfoKey = "free" | "privacy";

/** Anchor → what to open. Old section anchors keep working after the redesign. */
const tabAnchors: Record<string, TabKey> = {
  features: "search",
  search: "search",
  library: "library",
  rooms: "rooms",
  lyrics: "lyrics",
  interface: "lyrics",
  demo: "demo"
};

function FeatureTabs({ active, onChange }: { active: TabKey; onChange: (key: TabKey) => void }) {
  const refs = useRef<Record<string, HTMLButtonElement | null>>({});
  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const index = tabs.findIndex((tab) => tab.key === active);
    let next = index;
    if (event.key === "ArrowRight") next = (index + 1) % tabs.length;
    else if (event.key === "ArrowLeft") next = (index - 1 + tabs.length) % tabs.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = tabs.length - 1;
    else return;
    event.preventDefault();
    const key = tabs[next].key;
    onChange(key);
    refs.current[key]?.focus();
  };
  const Active = tabs.find((tab) => tab.key === active)!.load;

  return (
    <>
      <div className="tablist" role="tablist" aria-label="Возможности Resonance" onKeyDown={onKeyDown}>
        {tabs.map((tab) => (
          <button
            key={tab.key}
            ref={(node) => { refs.current[tab.key] = node; }}
            type="button"
            role="tab"
            id={`tab-${tab.key}`}
            aria-selected={tab.key === active}
            aria-controls={`panel-${tab.key}`}
            tabIndex={tab.key === active ? 0 : -1}
            className="tab"
            onClick={() => onChange(tab.key)}
          >
            {tab.label}
          </button>
        ))}
      </div>
      <div
        className="tabpanel"
        role="tabpanel"
        id={`panel-${active}`}
        aria-labelledby={`tab-${active}`}
        tabIndex={0}
      >
        <Suspense fallback={<div className="panel-loading" aria-busy="true">Загружаем…</div>}>
          <Active key={active} />
        </Suspense>
      </div>
    </>
  );
}

function Accordion({ summary, children }: { summary: ReactNode; children: ReactNode }) {
  return (
    <details>
      <summary>{summary} <Plus size={18} aria-hidden /></summary>
      <div className="accordion-body">{children}</div>
    </details>
  );
}

function App() {
  const { theme, toggle } = useTheme();
  const [tab, setTab] = useState<TabKey>("search");
  const [info, setInfo] = useState<InfoKey | null>(null);
  const [feature, setFeature] = useState<string | null>(null);

  /** Applies a hash route. Returns true when it was handled here (vs. a plain anchor). */
  const route = useCallback((hash: string) => {
    const id = decodeURIComponent(hash.replace(/^#/, ""));
    const isFeature = features5.some((item) => item.id === id);
    if (!isFeature) setFeature(null);
    if (id !== "free" && id !== "privacy") setInfo(null);
    if (tabAnchors[id]) {
      setTab(tabAnchors[id]);
      requestAnimationFrame(() => scrollTo("features"));
      return true;
    }
    if (id === "free" || id === "privacy") {
      scrollTo(id);
      setInfo(id);
      return true;
    }
    if (isFeature) {
      scrollTo(id);
      setFeature(id);
      return true;
    }
    return false;
  }, []);

  useEffect(() => {
    if (window.location.hash) route(window.location.hash);
    const onHash = () => route(window.location.hash);
    const onClick = (event: MouseEvent) => {
      if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      const link = (event.target as Element | null)?.closest?.("a[href^='#']");
      if (!link) return;
      const hash = link.getAttribute("href")!;
      if (route(hash)) {
        event.preventDefault();
        history.pushState(null, "", hash);
      }
    };
    window.addEventListener("hashchange", onHash);
    window.addEventListener("popstate", onHash);
    document.addEventListener("click", onClick);
    return () => {
      window.removeEventListener("hashchange", onHash);
      window.removeEventListener("popstate", onHash);
      document.removeEventListener("click", onClick);
    };
  }, [route]);

  const openFeature = features5.find((item) => item.id === feature);

  return (
    <div className="site-shell">
      <a className="skip-link" href="#main">К содержимому</a>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="Resonance — наверх">
          <span className="brand-mark"><img src="/assets/resonance-mark.png" alt="" width={24} height={24} /></span>
          <span>Resonance</span>
        </a>
        <nav aria-label="Основная навигация">
          <a href="#new">Что нового</a>
          <a href="#features">Возможности</a>
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

        <section className="new-section compact-section" id="new" aria-labelledby="new-title">
          <div className="compact-heading">
            <div>
              <p className="eyebrow">Что нового в 5.0</p>
              <h2 id="new-title">Всё вокруг <em>одного графа.</em></h2>
            </div>
            <p>
              Пятая версия связывает твою музыку, друзей и устройства. Каждая
              возможность доступна бесплатно с аккаунтом Resonance — открой
              карточку, чтобы узнать подробности.
            </p>
          </div>
          <ul className="new-grid">
            {features5.map(({ id, icon: Icon, title, teaser }) => (
              <li key={id} id={id}>
                <button type="button" className="new-card" aria-haspopup="dialog" onClick={() => setFeature(id)}>
                  <span className="new-icon"><Icon size={20} aria-hidden /></span>
                  <span className="new-card-text">
                    <span className="new-card-title">{title}</span>
                    <span className="new-card-teaser">{teaser}</span>
                  </span>
                  <ChevronRight className="new-card-chevron" size={18} aria-hidden />
                </button>
              </li>
            ))}
          </ul>
          <ul className="devices-strip" aria-label="Поддерживаемые устройства">
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

        <section className="features-section compact-section" id="features" aria-labelledby="features-title">
          <div className="compact-heading">
            <div>
              <p className="eyebrow">Возможности</p>
              <h2 id="features-title">Один плеер. <em>Все источники.</em></h2>
            </div>
            <p>
              Поиск по всем каталогам, перенос медиатеки, синхронные комнаты,
              тексты и живое демо Wave — переключай вкладки.
            </p>
          </div>
          <FeatureTabs active={tab} onChange={setTab} />
        </section>

        <section className="info-strip compact-section" aria-label="Бесплатно и приватно">
          <article className="info-card info-card-accent" id="free">
            <Heart size={24} aria-hidden />
            <div>
              <p className="eyebrow">Проект получил финансирование</p>
              <h2>Все возможности. <em>Бесплатно.</em></h2>
              <p>Без платных уровней, пробного периода и промокодов.</p>
            </div>
            <button type="button" className="button button-secondary" aria-haspopup="dialog" onClick={() => setInfo("free")}>
              Подробнее <ArrowRight size={16} aria-hidden />
            </button>
          </article>
          <article className="info-card" id="privacy">
            <ShieldCheck size={24} aria-hidden />
            <div>
              <p className="eyebrow">Приватность по архитектуре</p>
              <h2>Прокси остаётся <em>на сервере.</em></h2>
              <p>Адрес, логин и пароль прокси не попадают в приложение.</p>
            </div>
            <button type="button" className="button button-secondary" aria-haspopup="dialog" onClick={() => setInfo("privacy")}>
              Подробнее <ArrowRight size={16} aria-hidden />
            </button>
          </article>
        </section>

        <section className="help-section compact-section" id="start" aria-labelledby="start-title">
          <div className="help-layout">
            <div>
              <p className="eyebrow">Как начать</p>
              <h2 id="start-title">Три шага <em>до музыки.</em></h2>
              <ol className="steps-compact">
                <li>
                  <span className="step-index">01</span>
                  <div><h3>Установи Resonance</h3><p>Setup EXE или Portable ZIP для Windows, APK для Android, IPA для iOS.</p></div>
                </li>
                <li>
                  <span className="step-index">02</span>
                  <div><h3>Подключи источники</h3><p>Войди в SoundCloud, Яндекс Музыку, Spotify или VK — их каталоги появятся в едином поиске.</p></div>
                </li>
                <li>
                  <span className="step-index">03</span>
                  <div><h3>Слушай</h3><p>Живая очередь, синхронные тексты, комнаты и Wave — в одном нативном плеере.</p></div>
                </li>
              </ol>
            </div>

            <div className="help-lists">
              <div id="faq" className="anchor-target">
                <p className="eyebrow">Вопросы и ответы</p>
                <div className="faq-list">
                  <Accordion summary="Нужна ли подписка на источники — SoundCloud, Яндекс, Spotify, VK?">
                    <p>Сам Resonance полностью бесплатный. Доступ к каталогу и полным трекам зависит от правил выбранного источника: где-то достаточно серверного подключения Resonance, а где-то нужен твой аккаунт, токен или подписка самого музыкального сервиса.</p>
                  </Accordion>
                  <Accordion summary="Resonance действительно бесплатный?">
                    <p>Да. Проект получил финансирование, поэтому в Resonance нет платных уровней, пробного срока, промокодов и ограничений функций по оплате.</p>
                  </Accordion>
                  <Accordion summary="Что умеет Wave?">
                    <p>Wave собирает очередь по описанию настроения и перестраивает её на лету: «спокойнее», «больше нового», «без этого артиста». Только реальные треки из подключённых каталогов — без выдуманных названий.</p>
                  </Accordion>
                  <Accordion summary="Как работают комнаты?">
                    <p>Создатель комнаты получает ссылку-приглашение, а воспроизведение синхронизировано у всех участников. Создание и вход доступны бесплатно после входа в аккаунт Resonance.</p>
                  </Accordion>
                  <Accordion summary="Что с приватностью?">
                    <p>Прокси остаётся на сервере: клиент передаёт только переключатель его использования. Токены сервисов хранятся в защищённом хранилище устройства и отправляются только для выполнения запроса.</p>
                  </Accordion>
                </div>
              </div>

              <div id="knowledge" className="anchor-target">
                <p className="eyebrow">База знаний · подключение без догадок</p>
                <p className="knowledge-lead">
                  Токены — это пароли приложений. Не отправляйте их в чаты и не
                  сохраняйте в обычных заметках. Resonance хранит пользовательские
                  данные подключения в защищённом хранилище устройства.
                </p>
                <div className="faq-list knowledge-list">
                  <Accordion summary={<span className="kb-summary"><KeyRound size={16} aria-hidden /> Spotify · войти официально (рекомендуется)</span>}>
                    <ol>
                      <li>Откройте «Настройки → Подключения → Spotify».</li>
                      <li>Нажмите «Войти через Spotify» и подтвердите доступ к медиатеке и плейлистам.</li>
                      <li>Вернитесь в Resonance: приложение проверит вход и сохранит refresh-credential на устройстве.</li>
                    </ol>
                    <p className="knowledge-note">Ручной access token больше не нужен. Если вход не открывается, администратор сервера должен добавить точный HTTPS callback в Spotify Dashboard.</p>
                    <a href="https://developer.spotify.com/documentation/web-api/concepts/authorization" target="_blank" rel="noreferrer">Официальная документация Spotify <ArrowRight size={15} /></a>
                  </Accordion>
                  <Accordion summary={<span className="kb-summary"><KeyRound size={16} aria-hidden /> Яндекс Музыка · OAuth приложения</span>}>
                    <ol>
                      <li>Создайте OAuth-приложение в Яндекс ID и разрешите доступ только к нужным данным.</li>
                      <li>Пройдите авторизацию владельцем музыкальной библиотеки и получите OAuth-токен через настроенный redirect URI.</li>
                      <li>Вставьте токен в Resonance и дождитесь сообщения о проверке.</li>
                    </ol>
                    <p className="knowledge-note">Не копируйте cookie браузера и не используйте сайты-«генераторы токенов».</p>
                    <a href="https://yandex.ru/dev/id/doc/ru/concepts/ya-oauth-intro" target="_blank" rel="noreferrer">Документация Яндекс OAuth <ArrowRight size={15} /></a>
                  </Accordion>
                  <Accordion summary={<span className="kb-summary"><KeyRound size={16} aria-hidden /> SoundCloud · Client ID или OAuth</span>}>
                    <ol>
                      <li>Зарегистрируйте приложение в SoundCloud for Developers.</li>
                      <li>Возьмите Client ID в настройках приложения либо выполните OAuth flow для личного access token.</li>
                      <li>Вставьте значение в Resonance; cookie <code>oauth_token</code> не подходит.</li>
                    </ol>
                    <p className="knowledge-note">Если серверный Client ID уже настроен, этот шаг можно пропустить.</p>
                    <a href="https://developers.soundcloud.com/docs/api/guide" target="_blank" rel="noreferrer">SoundCloud API Guide <ArrowRight size={15} /></a>
                  </Accordion>
                  <Accordion summary={<span className="kb-summary"><KeyRound size={16} aria-hidden /> VK Музыка · токен с audio-доступом</span>}>
                    <ol>
                      <li>Создайте приложение в VK для разработчиков и настройте доверенный redirect URI.</li>
                      <li>Запросите пользовательский OAuth token только с необходимыми разрешениями.</li>
                      <li>Проверьте токен в Resonance. Если VK не выдал права audio, источник останется недоступен.</li>
                    </ol>
                    <p className="knowledge-note">Доступ к audio API ограничивается политикой VK и может быть недоступен обычным приложениям.</p>
                    <a href="https://dev.vk.com/ru/api/access-token/getting-started" target="_blank" rel="noreferrer">VK Access Token <ArrowRight size={15} /></a>
                  </Accordion>
                  <Accordion summary={<span className="kb-summary"><BookOpen size={16} aria-hidden /> Для администратора сервера</span>}>
                    <p>Видеоисточники включаются переменными <code>YOUTUBE_API_KEY</code>, <code>VIMEO_ACCESS_TOKEN</code>, <code>AUDIODB_API_KEY</code> и <code>PEXELS_API_KEY</code>. Spotify требует <code>SPOTIFY_CLIENT_ID</code>, а callback должен точно совпадать с <code>https://music.webcordes.ru/api/v1/auth/spotify/callback</code>.</p>
                  </Accordion>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="download-section compact-section" id="download" aria-labelledby="download-title">
          <div className="compact-heading">
            <div>
              <p className="eyebrow">Загрузки</p>
              <h2 id="download-title">Твои сервисы. <em>Один Resonance.</em></h2>
            </div>
            <p>
              Ссылки всегда ведут на актуальный релиз. iOS-сборка не подписана —
              её нужно подписать своим сертификатом.
            </p>
          </div>
          <ul className="platform-grid">
            {platforms.map(({ icon: Icon, name, note, href, cta }) => (
              <li key={name} className={href ? "platform-card" : "platform-card platform-soon"}>
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
          <a href="#library">Медиатека</a>
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

      <Modal
        open={openFeature != null}
        onClose={() => setFeature(null)}
        variant="drawer"
        eyebrow="Что нового в 5.0"
        title={openFeature?.title}
      >
        {openFeature ? (
          <>
            <span className="new-icon drawer-icon"><openFeature.icon size={24} aria-hidden /></span>
            <p className="drawer-lead">{openFeature.text}</p>
            <p className="drawer-note">Доступно бесплатно с аккаунтом Resonance.</p>
            <div className="drawer-actions">
              <a className="button button-primary" href="#download"
                onClick={(event) => {
                  event.preventDefault();
                  setFeature(null);
                  history.pushState(null, "", "#download");
                  setTimeout(() => scrollTo("download"), 0);
                }}
              >
                <Download size={16} aria-hidden /> Скачать Resonance
              </a>
            </div>
          </>
        ) : null}
      </Modal>

      <Modal open={info === "free"} onClose={() => setInfo(null)} eyebrow="Проект получил финансирование" title={<>Все возможности. <em>Бесплатно.</em></>}>
        <p className="drawer-lead">
          У Resonance больше нет платных уровней, пробного периода и
          промокодов. Скачивай приложение и используй все функции без оплаты.
        </p>
        <div className="info-grid">
          <article>
            <Volume2 size={22} aria-hidden />
            <h3>Полный плеер</h3>
            <p>Все поддерживаемые источники, единый поиск, импорт, тексты и Music Graph без ограничений Resonance.</p>
          </article>
          <article>
            <Heart size={22} aria-hidden />
            <h3>Wave без уровней</h3>
            <p>Персональные подборки, музыкальная память и управление очередью обычным языком доступны всем.</p>
          </article>
          <article>
            <Users size={22} aria-hidden />
            <h3>Комнаты для всех</h3>
            <p>Создавай комнаты, приглашай друзей и слушай синхронно. Для общей сессии нужен только бесплатный аккаунт.</p>
          </article>
        </div>
        <p className="drawer-note">Некоторые музыкальные сервисы могут требовать собственный аккаунт, токен или подписку по правилам самого источника. Resonance за доступ к своим функциям плату не берёт.</p>
      </Modal>

      <Modal open={info === "privacy"} onClose={() => setInfo(null)} eyebrow="Приватность по архитектуре" title={<>Прокси остаётся <em>на сервере.</em></>}>
        <p className="drawer-lead">
          Клиент передаёт только переключатель «использовать прокси».
          Адрес, логин и пароль не попадают в приложение и не выдаются API.
        </p>
        <p className="drawer-lead">
          Токены сервисов хранятся в защищённом хранилище устройства и
          отправляются только для выполнения запроса.
        </p>
      </Modal>
    </div>
  );
}

export default App;
