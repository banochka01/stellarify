import { Suspense, lazy, useCallback, useEffect, useRef, useState, type KeyboardEvent, type ReactNode } from "react";
import {
  ArrowRight,
  BookOpen,
  Car,
  Cast,
  Combine,
  Disc3,
  FlaskConical,
  KeyRound,
  Laptop,
  Mic2,
  Moon,
  Network,
  Plus,
  Sun,
  Trash2,
  UserPlus,
  Waves
} from "lucide-react";
import { ChannelSwitch, DownloadGrid, DownloadMenu } from "./components/DownloadMenu";
import { GraphHero } from "./components/GraphHero";
import { detectOs, formatDate, useRelease, type ChangelogEntry, type VisitorOs } from "./release";

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

const sources = [
  { name: "Яндекс Музыка", logo: "/assets/logos/yandex-music.svg" },
  { name: "SoundCloud", logo: "/assets/logos/soundcloud.svg" },
  { name: "YouTube", logo: "/assets/logos/youtube.svg" },
  { name: "Spotify", logo: "/assets/logos/spotify.svg" },
  { name: "VK Музыка", logo: "/assets/logos/vk.svg" }
];

/** Headline features of 5.0: full cards. */
const features = [
  { id: "graph", icon: Network, title: "Music Graph", text: "Каждый трек — узел графа: источники, артисты, альбомы и похожие записи. Переходи по музыке, как по карте." },
  { id: "friends", icon: UserPlus, title: "Друзья и совместимость", text: "Добавляй друзей и смотри процент совпадения: общие артисты, жанры и треки, которые стоит послушать вместе." },
  { id: "blend", icon: Combine, title: "Blend", text: "Общий плейлист для двоих или компании. Собирается из вкусов всех участников и обновляется сам." },
  { id: "dj", icon: Disc3, title: "DJ-комнаты", text: "Ведущий управляет очередью, слушатели предлагают треки и голосуют. Воспроизведение синхронно у всех." },
  { id: "sound", icon: Waves, title: "Чистый звук", text: "Нормализация громкости, gapless-переходы без пауз и lossless там, где источник его отдаёт." },
  { id: "cast", icon: Cast, title: "ТВ и колонки", text: "Трансляция на телевизоры и умные колонки в локальной сети — очередь остаётся в телефоне." }
];

/** The rest of the release: one line each. */
const extras = [
  { id: "car", icon: Car, title: "Авто, часы и ТВ", text: "Android Auto, CarPlay, Wear OS и Android TV." },
  { id: "artists", icon: Mic2, title: "Страницы артистов", text: "Дискография, популярное и связи в графе." },
  { id: "cleanup", icon: Trash2, title: "Чистка медиатеки", text: "Дубли, недоступные треки и пустые плейлисты." },
  { id: "beta", icon: FlaskConical, title: "Бета-канал", text: "Новые возможности раньше всех." },
  { id: "desktop", icon: Laptop, title: "macOS и Linux", text: "Сборки скоро появятся рядом с Windows." }
];

/* Heavy demo components are split into chunks and fetched only when their tab opens. */
const tabs = [
  { key: "search", label: "Поиск", load: lazy(() => import("./panels/SearchPanel")) },
  { key: "library", label: "Медиатека", load: lazy(() => import("./components/LibraryCinema").then((m) => ({ default: m.LibraryCinema }))) },
  { key: "rooms", label: "Комнаты", load: lazy(() => import("./panels/RoomsPanel")) },
  { key: "lyrics", label: "Тексты и интерфейс", load: lazy(() => import("./panels/LyricsPanel")) },
  { key: "demo", label: "Демо Wave", load: lazy(() => import("./components/DemoSandbox").then((m) => ({ default: m.DemoSandbox }))) }
] as const;

function scrollToId(id: string) {
  const reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  document.getElementById(id)?.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" });
}

type TabKey = (typeof tabs)[number]["key"];

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

/** Old anchors that now live inside another block. */
const anchorAliases: Record<string, string> = { free: "faq", privacy: "faq" };

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

  // On phones the tab strip scrolls sideways: keep the selected tab in sight.
  useEffect(() => {
    const node = refs.current[active];
    const strip = node?.parentElement;
    if (!node || !strip || strip.scrollWidth <= strip.clientWidth) return;
    const reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
    strip.scrollTo({ left: node.offsetLeft - (strip.clientWidth - node.offsetWidth) / 2, behavior: reduce ? "auto" : "smooth" });
  }, [active]);

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
      <div className="tabpanel" role="tabpanel" id={`panel-${active}`} aria-labelledby={`tab-${active}`}>
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
      <summary><span>{summary}</span> <Plus size={18} aria-hidden /></summary>
      <div className="accordion-body">{children}</div>
    </details>
  );
}

const CHANGELOG_PREVIEW = 4;

function Changelog({ entries }: { entries: ChangelogEntry[] }) {
  const [expanded, setExpanded] = useState(false);
  const shown = expanded ? entries : entries.slice(0, CHANGELOG_PREVIEW);
  const hidden = entries.length - shown.length;

  return (
    <>
      <ol className="changelog-list">
        {shown.map((entry) => (
          <li key={entry.version} className="changelog-entry">
            <div className="changelog-meta">
              <span className="changelog-version">{entry.version}</span>
              <time dateTime={entry.date}>{formatDate(entry.date)}</time>
            </div>
            <div className="changelog-body">
              {/* "Resonance 5.0.6" repeats the version badge; only named releases get a title. */}
              {entry.title && entry.title !== `Resonance ${entry.version}` ? <h3>{entry.title}</h3> : null}
              <ul>
                {entry.highlights.map((item) => <li key={item}>{item}</li>)}
              </ul>
            </div>
          </li>
        ))}
      </ol>
      {hidden > 0 ? (
        <button type="button" className="button button-secondary changelog-more" onClick={() => setExpanded(true)}>
          Показать ранние версии · {hidden}
        </button>
      ) : null}
    </>
  );
}

const navLinks = [
  { href: "#features", section: "features", label: "Возможности" },
  { href: "#faq", section: "start", label: "Вопросы" },
  { href: "#download", section: "download", label: "Загрузки" },
  { href: "#changelog", section: "changelog", label: "Обновления" }
];

function App() {
  const { theme, toggle } = useTheme();
  const release = useRelease();
  const [os] = useState<VisitorOs>(detectOs);
  const [tab, setTab] = useState<TabKey>("search");
  const [scrolled, setScrolled] = useState(false);
  const [section, setSection] = useState<string | null>(null);
  const hasChangelog = release.changelog.length > 0;

  /** Applies a hash route. Returns true when it was handled here (vs. a plain anchor). */
  const route = useCallback((hash: string) => {
    const id = decodeURIComponent(hash.replace(/^#/, ""));
    if (tabAnchors[id]) {
      setTab(tabAnchors[id]);
      requestAnimationFrame(() => scrollToId("features"));
      return true;
    }
    if (anchorAliases[id]) {
      scrollToId(anchorAliases[id]);
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

  // The header gets a solid backdrop once the page moves under it.
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  // Sections fade in once, and the nav marks the one being read.
  useEffect(() => {
    if (!("IntersectionObserver" in window)) return;
    const sections = Array.from(document.querySelectorAll<HTMLElement>("main .section"));
    const reveal = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          reveal.unobserve(entry.target);
        }
      }
    }, { rootMargin: "0px 0px -10% 0px" });
    const spy = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) setSection(entry.target.id);
      }
    }, { rootMargin: "-40% 0px -55% 0px" });
    for (const node of sections) {
      node.classList.add("reveal");
      reveal.observe(node);
      spy.observe(node);
    }
    const hero = document.getElementById("top");
    if (hero) spy.observe(hero);
    return () => {
      reveal.disconnect();
      spy.disconnect();
    };
  }, [hasChangelog]);

  return (
    <div className="site-shell">
      <a className="skip-link" href="#main">К содержимому</a>
      <header className={`site-header${scrolled ? " is-scrolled" : ""}`}>
        <div className="site-header-inner">
          <a className="brand" href="#top" aria-label="Resonance — наверх">
            <span className="brand-mark"><img src="/assets/resonance-mark.webp" alt="" width={24} height={24} /></span>
            <span>Resonance</span>
          </a>
          <nav aria-label="Основная навигация">
            {navLinks.filter((link) => link.section !== "changelog" || hasChangelog).map((link) => (
              <a key={link.href} href={link.href} aria-current={section === link.section ? "true" : undefined}>{link.label}</a>
            ))}
          </nav>
          <div className="header-actions">
            <button
              type="button"
              className="theme-toggle"
              onClick={toggle}
              aria-label={theme === "dark" ? "Включить светлую тему" : "Включить тёмную тему"}
            >
              {theme === "dark" ? <Sun size={18} aria-hidden /> : <Moon size={18} aria-hidden />}
            </button>
            <DownloadMenu os={os} release={release} compact />
            <a className="header-cta" href="#download">Скачать</a>
          </div>
        </div>
      </header>

      <main id="main">
        <section className="hero" id="top">
          <div className="hero-copy">
            <p className="eyebrow">Resonance 5.0 · Graph</p>
            <h1>Музыка —<br />это <em>связи</em>.</h1>
            <p className="hero-lead">
              Один плеер для всех твоих сервисов. Общий поиск, медиатека
              и комнаты, где друзья слушают синхронно.
            </p>
            <ul className="source-strip" aria-label="Поддерживаемые источники">
              {sources.map((source) => (
                <li key={source.name}>
                  <img src={source.logo} alt="" width={16} height={16} />
                  {source.name}
                </li>
              ))}
            </ul>
            <div className="hero-actions">
              <DownloadMenu os={os} release={release} />
              <a className="button button-secondary" href="#features">
                Возможности <ArrowRight size={17} aria-hidden />
              </a>
            </div>
            <p className="release-note">
              {[release.version && `Версия ${release.version}`, "бесплатно, без подписки"].filter(Boolean).join(" · ")}
              {release.version && hasChangelog ? <> · <a href="#changelog">что изменилось</a></> : null}
            </p>
          </div>
          <div className="hero-visual">
            <GraphHero />
          </div>
        </section>

        <section className="section section-alt" id="new" aria-labelledby="new-title">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Что нового в 5.0</p>
              <h2 id="new-title">Всё вокруг <em>одного графа.</em></h2>
            </div>
            <p>Музыка, друзья и устройства в одном аккаунте. Всё доступно бесплатно после входа в Resonance.</p>
          </div>
          <ul className="new-grid">
            {features.map(({ id, icon: Icon, title, text }) => (
              <li key={id} id={id} className="new-card">
                <span className="new-icon"><Icon size={20} aria-hidden /></span>
                <h3>{title}</h3>
                <p>{text}</p>
              </li>
            ))}
          </ul>
          <ul className="extras-list" aria-label="Ещё в версии 5.0">
            {extras.map(({ id, icon: Icon, title, text }) => (
              <li key={id} id={id}>
                <Icon size={18} aria-hidden />
                <span>
                  <b>{title}</b>
                  <span>{text}</span>
                </span>
              </li>
            ))}
          </ul>
        </section>

        <section className="section" id="features" aria-labelledby="features-title">
          <div className="section-heading">
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

        <section className="section section-alt" id="start" aria-labelledby="start-title">
          <div className="help-layout">
            <div className="help-start">
              <p className="eyebrow">Как начать</p>
              <h2 id="start-title">Три шага <em>до музыки.</em></h2>
              <ol className="steps">
                <li>
                  <span className="step-index" aria-hidden>01</span>
                  <div><h3>Установи Resonance</h3><p>Установщик или Portable ZIP для Windows, APK для Android, IPA для iOS.</p></div>
                </li>
                <li>
                  <span className="step-index" aria-hidden>02</span>
                  <div><h3>Подключи источники</h3><p>Войди в SoundCloud, Яндекс Музыку, Spotify или VK — их каталоги появятся в едином поиске.</p></div>
                </li>
                <li>
                  <span className="step-index" aria-hidden>03</span>
                  <div><h3>Слушай</h3><p>Живая очередь, синхронные тексты, комнаты и Wave — в одном нативном плеере.</p></div>
                </li>
              </ol>
            </div>

            <div className="help-lists">
              <div id="faq" className="anchor-target">
                <h3 className="eyebrow">Вопросы и ответы</h3>
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
                <h3 className="eyebrow">Подключение сервисов</h3>
                <p className="knowledge-lead">
                  Токены — это пароли приложений. Не отправляй их в чаты и не
                  храни в обычных заметках: Resonance держит данные подключения
                  в защищённом хранилище устройства.
                </p>
                <div className="faq-list">
                  <Accordion summary={<span className="kb-summary"><KeyRound size={16} aria-hidden /> Spotify · официальный вход (рекомендуется)</span>}>
                    <ol>
                      <li>Открой «Настройки → Подключения → Spotify».</li>
                      <li>Нажми «Войти через Spotify» и подтверди доступ к медиатеке и плейлистам.</li>
                      <li>Вернись в Resonance: приложение проверит вход и сохранит ключ обновления на устройстве.</li>
                    </ol>
                    <p className="knowledge-note">Ручной access token больше не нужен. Если вход не открывается, администратор сервера должен добавить точный HTTPS callback в Spotify Dashboard.</p>
                    <a href="https://developer.spotify.com/documentation/web-api/concepts/authorization" target="_blank" rel="noreferrer">Официальная документация Spotify <ArrowRight size={15} aria-hidden /></a>
                  </Accordion>
                  <Accordion summary={<span className="kb-summary"><KeyRound size={16} aria-hidden /> Яндекс Музыка · OAuth приложения</span>}>
                    <ol>
                      <li>Создай OAuth-приложение в Яндекс ID и разреши доступ только к нужным данным.</li>
                      <li>Пройди авторизацию под аккаунтом с музыкальной библиотекой и получи OAuth-токен через настроенный redirect URI.</li>
                      <li>Вставь токен в Resonance и дождись сообщения о проверке.</li>
                    </ol>
                    <p className="knowledge-note">Не копируй cookie браузера и не пользуйся сайтами-«генераторами токенов».</p>
                    <a href="https://yandex.ru/dev/id/doc/ru/concepts/ya-oauth-intro" target="_blank" rel="noreferrer">Документация Яндекс OAuth <ArrowRight size={15} aria-hidden /></a>
                  </Accordion>
                  <Accordion summary={<span className="kb-summary"><KeyRound size={16} aria-hidden /> SoundCloud · Client ID или OAuth</span>}>
                    <ol>
                      <li>Зарегистрируй приложение в SoundCloud for Developers.</li>
                      <li>Возьми Client ID в настройках приложения либо пройди OAuth для личного access token.</li>
                      <li>Вставь значение в Resonance; cookie <code>oauth_token</code> не подходит.</li>
                    </ol>
                    <p className="knowledge-note">Если серверный Client ID уже настроен, этот шаг можно пропустить.</p>
                    <a href="https://developers.soundcloud.com/docs/api/guide" target="_blank" rel="noreferrer">SoundCloud API Guide <ArrowRight size={15} aria-hidden /></a>
                  </Accordion>
                  <Accordion summary={<span className="kb-summary"><KeyRound size={16} aria-hidden /> VK Музыка · токен с доступом к аудио</span>}>
                    <ol>
                      <li>Создай приложение в VK для разработчиков и настрой доверенный redirect URI.</li>
                      <li>Запроси пользовательский OAuth-токен только с необходимыми разрешениями.</li>
                      <li>Проверь токен в Resonance. Если VK не выдал права audio, источник останется недоступен.</li>
                    </ol>
                    <p className="knowledge-note">Доступ к audio API ограничен политикой VK и может быть недоступен обычным приложениям.</p>
                    <a href="https://dev.vk.com/ru/api/access-token/getting-started" target="_blank" rel="noreferrer">VK Access Token <ArrowRight size={15} aria-hidden /></a>
                  </Accordion>
                  <Accordion summary={<span className="kb-summary"><BookOpen size={16} aria-hidden /> Для администратора сервера</span>}>
                    <p>Видеоисточники включаются переменными <code>YOUTUBE_API_KEY</code>, <code>VIMEO_ACCESS_TOKEN</code>, <code>AUDIODB_API_KEY</code> и <code>PEXELS_API_KEY</code>. Spotify требует <code>SPOTIFY_CLIENT_ID</code>, а callback должен точно совпадать с <code>https://music.webcordes.ru/api/v1/auth/spotify/callback</code>.</p>
                  </Accordion>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="section" id="download" aria-labelledby="download-title">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Загрузки{release.version ? ` · версия ${release.version}` : ""}</p>
              <h2 id="download-title">Твои сервисы. <em>Один Resonance.</em></h2>
            </div>
            <p>Ссылки всегда ведут на актуальный релиз. Сборка для iOS не подписана — её нужно подписать своим сертификатом.</p>
          </div>
          <div className="channel-row">
            <ChannelSwitch />
            <p>Alpha — Resonance α: новый интерфейс с нуля. Отдельное приложение, ставится рядом со стабильным.</p>
          </div>
          <DownloadGrid os={os} release={release} />
        </section>

        {hasChangelog ? (
          <section className="section section-alt" id="changelog" aria-labelledby="changelog-title">
            <div className="section-heading">
              <div>
                <p className="eyebrow">История версий</p>
                <h2 id="changelog-title">Что <em>изменилось</em>.</h2>
              </div>
              <p>Стабильные релизы, новые сверху. Приложение обновляется по тем же ссылкам.</p>
            </div>
            <Changelog entries={release.changelog} />
          </section>
        ) : null}
      </main>

      <footer>
        <a className="brand" href="#top" aria-label="Resonance — наверх">
          <span className="brand-mark"><img src="/assets/resonance-mark.webp" alt="" width={22} height={22} /></span>
          Resonance
        </a>
        <nav className="footer-nav" aria-label="Разделы лендинга">
          <a href="#features">Возможности</a>
          <a href="#download">Скачать</a>
          {hasChangelog ? <a href="#changelog">Обновления</a> : null}
          <a href="#knowledge">Подключение сервисов</a>
          <a href="#faq">Вопросы</a>
        </nav>
        <p className="footer-meta">
          <span>© 2026 WebCord</span>
          <span>Windows · Android · iOS · macOS и Linux скоро</span>
        </p>
      </footer>
    </div>
  );
}

export default App;
