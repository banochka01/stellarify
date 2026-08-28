import { useLayoutEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import {
  ArrowDown,
  ArrowRight,
  Apple,
  Download,
  Heart,
  Layers3,
  Play,
  Search,
  ShieldCheck,
  Smartphone,
  Volume2
} from "lucide-react";

gsap.registerPlugin(ScrollTrigger);

const downloads = {
  windows: "/downloads/windows",
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
              Подключай свои сервисы. Находи нужный трек. Слушай в едином
              интерфейсе Resonance.
            </p>
            <div className="hero-actions">
              <a className="button button-primary" href={downloads.windows}>
                <Download size={18} /> Скачать для Windows
              </a>
              <a className="button button-secondary" href={downloads.android}>
                <Smartphone size={18} /> Версия для Android
              </a>
              <a className="button button-secondary" href={downloads.ios}>
                <Apple size={18} /> Unsigned IPA
              </a>
            </div>
            <p className="release-note">Windows · Android · iOS unsigned</p>
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
              Resonance ищет музыку сразу в подключённых сервисах и объединяет
              результаты в одном чистом списке.
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
              <span><Play size={24} /></span>
              <h3>Единое воспроизведение</h3>
              <p>Треки из разных источников играют в одном плеере.</p>
            </article>
            <article data-reveal>
              <span><Heart size={24} /></span>
              <h3>Твой выбор</h3>
              <p>Сохраняй, собирай очередь и управляй музыкой по-своему.</p>
            </article>
          </div>
        </section>

        <section className="interface-section" id="interface">
          <div className="interface-copy" data-reveal>
            <p className="eyebrow">Один выразительный плеер</p>
            <h2>Не ещё один<br />клон стриминга.</h2>
            <p>
              Чёрный editorial-интерфейс держит музыку в центре: крупная
              обложка, ясный поиск и компактная строка следующего трека.
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
            <a className="button button-primary" href={downloads.windows}>Скачать для Windows</a>
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
