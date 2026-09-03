import { useLayoutEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import {
  ArrowDown,
  ArrowRight,
  Apple,
  Clock3,
  Download,
  FileText,
  Heart,
  Layers3,
  Search,
  ShieldCheck,
  Smartphone,
  Ticket,
  Users,
  Volume2
} from "lucide-react";

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
          const { reduce, desktop } = conditions as {
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
          gsap.from(".hero-orbit", {
            autoAlpha: 0,
            scale: 0.84,
            rotation: -8,
            duration: 1.35,
            ease: "power3.out"
          });
          gsap.to(".hero-orbit", {
            rotation: desktop ? 4 : 2,
            yPercent: -3,
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

          gsap.fromTo(
            ".source-map",
            { scale: 0.84, rotation: -4 },
            {
              scale: 1,
              rotation: 0,
              ease: "none",
              scrollTrigger: {
                trigger: ".search-scene",
                start: "top 88%",
                end: "center 48%",
                scrub: 1
              }
            }
          );
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
          <a href="#plans">Подписки</a>
          <a href="#interface">Интерфейс</a>
          <a href="#privacy">Приватность</a>
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
              Опиши настроение обычными словами. Wave поймёт контекст, учтёт
              твой вкус и соберёт живую очередь из подключённых источников.
            </p>
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
            <p className="release-note">Resonance 1.3 Lyrics Network · Несколько Lyrics-источников · Windows Setup EXE · Android debug-signed · iOS unsigned</p>
          </div>
          <div className="hero-visual" aria-hidden="true">
            <img className="hero-orbit" src="/assets/resonance-hero-orbit.png" alt="" />
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
              Resonance ищет музыку в SoundCloud и Яндекс Музыке, объединяет
              результаты и воспроизводит их только в собственном плеере.
            </p>
          </div>

          <div className="search-scene" data-reveal>
            <img className="source-map" src="/assets/resonance-source-map.png" alt="" />
            <span className="source-label source-label-left">SoundCloud</span>
            <span className="source-label source-label-right">Яндекс Музыка</span>
          </div>

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

        <section className="plans-section" id="plans">
          <div className="plans-heading" data-reveal>
            <div>
              <p className="eyebrow">Доступ без скрытых условий</p>
              <h2>Сутки на знакомство.<br /><em>Дальше — твой план.</em></h2>
            </div>
            <p>
              Оплаченный промокод вводится внутри Resonance и открывает выбранный
              тариф на указанный срок. Подписка источника приобретается отдельно.
            </p>
          </div>

          <div className="guest-pass" data-reveal>
            <span className="plan-icon"><Clock3 size={24} /></span>
            <div>
              <p className="plan-kicker">Гостевой доступ</p>
              <h3>24 часа · только SoundCloud</h3>
            </div>
            <p>Поиск и наш плеер, локальная библиотека и до трёх подборок Wave. Без облака и комнат.</p>
          </div>

          <div className="plans-grid">
            <article className="plan-card" data-reveal>
              <div className="plan-card-top">
                <span className="plan-icon"><Ticket size={22} /></span>
                <p className="plan-kicker">Base</p>
              </div>
              <h3>Для личного прослушивания</h3>
              <ul>
                <li>SoundCloud и Яндекс Музыка</li>
                <li>Облачная библиотека и импорт</li>
                <li>Стандартная Wave</li>
                <li>Вход в комнаты · 2 устройства</li>
              </ul>
            </article>
            <article className="plan-card plan-card-accent" data-reveal>
              <div className="plan-card-top">
                <span className="plan-icon"><Volume2 size={22} /></span>
                <p className="plan-kicker">Plus</p>
              </div>
              <h3>Для музыки без компромиссов</h3>
              <ul>
                <li>Всё из Base</li>
                <li>Wave обычным языком и музыкальная память</li>
                <li>Создание и вход в комнаты</li>
                <li>До 10 устройств</li>
              </ul>
            </article>
            <article className="plan-card" data-reveal>
              <div className="plan-card-top">
                <span className="plan-icon"><Users size={22} /></span>
                <p className="plan-kicker">Family</p>
              </div>
              <h3>Для пяти отдельных аккаунтов</h3>
              <ul>
                <li>Всё из Plus</li>
                <li>Владелец и до 4 участников</li>
                <li>Отдельные библиотеки и настройки</li>
                <li>До 10 устройств на участника</li>
              </ul>
            </article>
          </div>
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
        <span>© 2026 WebCord</span>
        <span>Windows · Android · iOS</span>
      </footer>
    </div>
  );
}

export default App;
