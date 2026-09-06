import { useEffect, useRef, useState, type FormEvent, type MouseEvent } from "react";
import { Check, Link2, Music, Pause, Play, SkipBack, SkipForward, Sparkles } from "lucide-react";
import { SESSION_TRACKS, type SessionTrack } from "../session";

type Track = SessionTrack;

const byTitle = (title: string) =>
  SESSION_TRACKS.find((track) => track.title.startsWith(title)) as SessionTrack;

const POOLS = {
  calm: [
    byTitle("Night, Blooming Jasmine"),
    byTitle("так совпало"),
    byTitle("Noir by anoufie"),
    byTitle("Тревога"),
    byTitle("1cePillow"),
    byTitle("crush")
  ],
  fresh: [
    byTitle("crush"),
    byTitle("Выходной"),
    byTitle("Surround Sound"),
    byTitle("Can't Tell Me Nothing"),
    byTitle("так совпало"),
    byTitle("Night, Blooming Jasmine")
  ],
  instrumental: [
    byTitle("Noir by anoufie"),
    byTitle("1cePillow"),
    byTitle("так совпало"),
    byTitle("Тревога"),
    byTitle("Night, Blooming Jasmine"),
    byTitle("crush")
  ],
  mixed: [
    byTitle("crush"),
    byTitle("Выходной"),
    byTitle("Surround Sound"),
    byTitle("так совпало"),
    byTitle("Can't Tell Me Nothing"),
    byTitle("Noir by anoufie")
  ]
} satisfies Record<string, Track[]>;

type PoolKey = keyof typeof POOLS;

const CHIPS: { label: string; pool: PoolKey }[] = [
  { label: "спокойнее", pool: "calm" },
  { label: "больше нового", pool: "fresh" },
  { label: "без вокала", pool: "instrumental" },
  { label: "перемешать", pool: "mixed" }
];

const LYRICS = [
  { at: 0.02, text: "Город гудит на низкой частоте," },
  { at: 0.14, text: "фары режут ночь пополам." },
  { at: 0.27, text: "Каждый трек ложится на ритм шагов —" },
  { at: 0.4, text: "и очередь ловит тебя, как эхо." },
  { at: 0.55, text: "Строка загорается раньше бита," },
  { at: 0.68, text: "ни одной не теряя." },
  { at: 0.82, text: "А если бросишь «побыстрее» —" },
  { at: 0.92, text: "ночь ускорится. Она слышит." }
];

const BASE_PROMPT = "вечерний фокус для работы";

function pickPool(prompt: string): PoolKey {
  const p = prompt.toLowerCase();
  if (p.includes("спокой") || p.includes("тих") || p.includes("сон")) return "calm";
  if (p.includes("нов") || p.includes("свеж")) return "fresh";
  if (p.includes("вокал") || p.includes("инструмент")) return "instrumental";
  return "mixed";
}

function formatTime(total: number) {
  const m = Math.floor(total / 60);
  const s = Math.floor(total % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export function DemoSandbox() {
  const [prompt, setPrompt] = useState(BASE_PROMPT);
  const [queue, setQueue] = useState<Track[]>(POOLS.mixed);
  const [current, setCurrent] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const [regen, setRegen] = useState(0);
  const [copied, setCopied] = useState(false);
  const progressRef = useRef(0);
  const track = queue[current];

  useEffect(() => {
    if (!playing || !track) return;
    let raf = 0;
    let last = performance.now();
    let reported = -1;
    const tick = (now: number) => {
      const dt = (now - last) / 1000;
      last = now;
      const next = Math.min(1, progressRef.current + (dt * 10) / track.duration);
      progressRef.current = next;
      if (next >= 1) {
        if (current < queue.length - 1) {
          setCurrent(current + 1);
          progressRef.current = 0;
          setProgress(0);
          return;
        }
        setPlaying(false);
        setProgress(1);
        return;
      }
      if (Math.abs(next - reported) > 0.003) {
        reported = next;
        setProgress(next);
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [playing, current, queue, track]);

  const regenerate = (pool: PoolKey, label?: string) => {
    const shuffled = [...POOLS[pool]].sort(() => Math.random() - 0.5);
    progressRef.current = 0;
    setQueue(shuffled);
    setCurrent(0);
    setProgress(0);
    setPlaying(true);
    setRegen((r) => r + 1);
    if (label) {
      setPrompt((p) => `${p.trim().replace(/[.,]$/, "")}, ${label}`);
    }
  };

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    regenerate(pickPool(prompt));
  };

  const selectRow = (index: number) => {
    progressRef.current = 0;
    setCurrent(index);
    setProgress(0);
  };

  const seek = (event: MouseEvent<HTMLDivElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const ratio = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width));
    progressRef.current = ratio;
    setProgress(ratio);
  };

  const copyInvite = async () => {
    try {
      await navigator.clipboard.writeText(`${window.location.origin}${window.location.pathname}#demo`);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      setCopied(false);
    }
  };

  if (!track) return null;

  let active = -1;
  for (let i = 0; i < LYRICS.length; i += 1) {
    if (progress >= LYRICS[i].at) active = i;
  }

  return (
    <section className="demo-section" id="demo">
      <div className="demo-heading" data-reveal>
        <div>
          <p className="eyebrow">Живое демо</p>
          <h2>Попробуй Wave.<br /><em>Прямо здесь.</em></h2>
        </div>
        <p>
          Мок-версия настоящего плеера: опиши настроение или нажми подсказку —
          очередь пересоберётся. Настоящая Wave с твоей библиотекой ждёт внутри
          Resonance.
        </p>
      </div>

      <div className="demo-layout" data-reveal>
        <div className="demo-pane">
          <form className="demo-form" onSubmit={onSubmit}>
            <input
              className="demo-input"
              value={prompt}
              onChange={(event) => setPrompt(event.target.value)}
              placeholder="опиши настроение…"
              aria-label="Запрос для Wave"
            />
            <button className="demo-rebuild" type="submit">
              <Sparkles size={15} /> Пересобрать
            </button>
          </form>
          <div className="demo-chips">
            {CHIPS.map((chip) => (
              <button
                key={chip.label}
                type="button"
                className="demo-chip"
                onClick={() => regenerate(chip.pool, chip.label)}
              >
                {chip.label}
              </button>
            ))}
          </div>
          <div className="demo-queue">
            {queue.map((item, i) => (
              <button
                key={`${regen}-${item.title}`}
                type="button"
                className={`demo-row${i === current ? " is-current" : ""}`}
                style={{ animationDelay: `${i * 60}ms` }}
                onClick={() => selectRow(i)}
              >
                <span className="queue-row-index">
                  {i === current && playing ? (
                    <span className="eq"><i /><i /><i /><i /></span>
                  ) : (
                    String(i + 1).padStart(2, "0")
                  )}
                </span>
                {item.cover ? (
                  <img className="queue-row-cover queue-row-cover-img" src={item.cover} alt="" loading="lazy" />
                ) : (
                  <span className="queue-row-cover" style={{ background: item.tint }}><Music size={17} /></span>
                )}
                <span>
                  <span className="queue-row-title">{item.title}</span>
                  <span className="queue-row-artist">{item.artist}</span>
                </span>
                <span className="queue-source" data-source={item.source}>{item.source}</span>
              </button>
            ))}
          </div>
        </div>

        <div className="demo-pane">
          <div
            className="demo-player-cover"
            style={track.cover ? { backgroundImage: `url(${track.cover})`, backgroundSize: "cover", backgroundPosition: "center" } : { background: track.tint }}
          >
            {track.cover ? null : <Music size={44} />}
          </div>
          <span className="queue-source" data-source={track.source}>{track.source}</span>
          <h3 className="demo-player-title">{track.title}</h3>
          <p className="demo-player-artist">{track.artist}</p>
          <div className="demo-controls">
            <button
              className="demo-btn"
              type="button"
              aria-label="Предыдущий трек"
              disabled={current === 0}
              onClick={() => selectRow(Math.max(0, current - 1))}
            >
              <SkipBack size={18} />
            </button>
            <button
              className="demo-btn demo-btn-play"
              type="button"
              aria-label={playing ? "Пауза" : "Играть"}
              onClick={() => setPlaying(!playing)}
            >
              {playing ? <Pause size={20} /> : <Play size={20} />}
            </button>
            <button
              className="demo-btn"
              type="button"
              aria-label="Следующий трек"
              disabled={current === queue.length - 1}
              onClick={() => selectRow(Math.min(queue.length - 1, current + 1))}
            >
              <SkipForward size={18} />
            </button>
          </div>
          <div className="demo-progress" onClick={seek} role="presentation">
            <span style={{ width: `${progress * 100}%` }} />
          </div>
          <div className="demo-times">
            <span>{formatTime(progress * track.duration)}</span>
            <span>{formatTime(track.duration)}</span>
          </div>
          <div className="demo-lyrics">
            {LYRICS.map((line, i) => (
              <p key={line.text} className={`demo-lyric${i === active ? " is-active" : ""}`}>
                {line.text}
              </p>
            ))}
          </div>
          <button className="demo-invite" type="button" onClick={copyInvite}>
            {copied ? <Check size={14} /> : <Link2 size={14} />}
            {copied ? "Ссылка скопирована" : "Пригласить в комнату — скопировать ссылку"}
          </button>
        </div>
      </div>
    </section>
  );
}
