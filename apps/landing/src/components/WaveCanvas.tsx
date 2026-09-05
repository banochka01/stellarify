import { useEffect, useRef, useState } from "react";
import { Volume2, VolumeX } from "lucide-react";

function createWaveAudio() {
  const ctx = new AudioContext();
  const master = ctx.createGain();
  master.gain.value = 0;
  const filter = ctx.createBiquadFilter();
  filter.type = "lowpass";
  filter.frequency.value = 620;
  filter.Q.value = 0.7;
  const analyser = ctx.createAnalyser();
  analyser.fftSize = 1024;
  const freqs = [110, 164.81, 220, 329.63];
  const gains = [0.5, 0.32, 0.26, 0.1];
  const oscillators = freqs.map((frequency, i) => {
    const osc = ctx.createOscillator();
    osc.type = i === 3 ? "triangle" : "sine";
    osc.frequency.value = frequency * (i % 2 ? 1.0015 : 0.9985);
    const gain = ctx.createGain();
    gain.gain.value = gains[i];
    osc.connect(gain);
    gain.connect(filter);
    osc.start();
    return osc;
  });
  const lfo = ctx.createOscillator();
  lfo.frequency.value = 0.08;
  const lfoGain = ctx.createGain();
  lfoGain.gain.value = 170;
  lfo.connect(lfoGain);
  lfoGain.connect(filter.frequency);
  lfo.start();
  filter.connect(master);
  master.connect(analyser);
  analyser.connect(ctx.destination);
  master.gain.linearRampToValueAtTime(0.05, ctx.currentTime + 1.4);
  const data = new Uint8Array(analyser.fftSize);
  const stop = () => {
    master.gain.cancelScheduledValues(ctx.currentTime);
    master.gain.setTargetAtTime(0, ctx.currentTime, 0.15);
    window.setTimeout(() => {
      oscillators.forEach((osc) => osc.stop());
      lfo.stop();
      void ctx.close();
    }, 500);
  };
  return { analyser, data, stop };
}

type WaveAudio = ReturnType<typeof createWaveAudio>;

export function WaveCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const audioRef = useRef<WaveAudio | null>(null);
  const [soundOn, setSoundOn] = useState(false);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    let raf = 0;
    let width = 0;
    let height = 0;
    let time = reduce ? 2.6 : 0;
    const pointer = { x: 0.62, y: 0.42, tx: 0.62, ty: 0.42 };
    let energy = 0.12;

    const resize = () => {
      const parent = canvas.parentElement;
      if (!parent) return;
      width = parent.clientWidth;
      height = parent.clientHeight;
      canvas.width = Math.max(1, Math.round(width * dpr));
      canvas.height = Math.max(1, Math.round(height * dpr));
    };
    resize();
    const observer = new ResizeObserver(resize);
    if (canvas.parentElement) observer.observe(canvas.parentElement);
    const onMove = (event: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      pointer.tx = (event.clientX - rect.left) / Math.max(rect.width, 1);
      pointer.ty = (event.clientY - rect.top) / Math.max(rect.height, 1);
    };
    window.addEventListener("pointermove", onMove, { passive: true });

    const draw = () => {
      time += 0.016;
      pointer.x += (pointer.tx - pointer.x) * 0.07;
      pointer.y += (pointer.ty - pointer.y) * 0.07;
      const audio = audioRef.current;
      let audioLevel = 0;
      if (audio) {
        audio.analyser.getByteTimeDomainData(audio.data);
        let sum = 0;
        let count = 0;
        for (let i = 0; i < audio.data.length; i += 4) {
          const value = (audio.data[i] - 128) / 128;
          sum += value * value;
          count += 1;
        }
        audioLevel = Math.min(1, Math.sqrt(sum / Math.max(count, 1)) * 3.4);
      }
      const beat = Math.pow(Math.max(0, Math.sin(time * 2.1)), 8);
      const target = Math.max(beat * 0.5, audioLevel, 0.1);
      energy += (target - energy) * 0.09;
      const fade = Math.max(0, 1 - window.scrollY / (window.innerHeight * 1.15));
      const intensity = energy * (0.35 + 0.65 * fade);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, width, height);
      const middle = height / 2;
      for (let i = 0; i < 6; i += 1) {
        ctx.beginPath();
        const amplitude = height * 0.13 * (1 - i * 0.12) * (0.5 + intensity * 1.6);
        const frequency = 1.6 + i * 0.55;
        const speed = 0.7 + i * 0.22;
        for (let x = 0; x <= width; x += 6) {
          const nx = x / Math.max(width, 1);
          const envelope = Math.pow(Math.sin(Math.PI * nx), 1.5);
          const y = middle
            + Math.sin(nx * Math.PI * 2 * frequency + time * speed + i * 1.7) * amplitude * envelope
            + Math.sin(nx * Math.PI * 2 * frequency * 2.7 - time * speed * 1.6) * amplitude * 0.22 * envelope
            + (pointer.y - 0.5) * height * 0.14 * envelope * (i < 2 ? 1 : 0.4);
          if (x === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        if (i === 0) {
          ctx.strokeStyle = "rgba(240,90,73,.95)";
          ctx.lineWidth = 2.4;
          ctx.shadowColor = "rgba(240,90,73,.5)";
          ctx.shadowBlur = 16;
        } else {
          ctx.strokeStyle = `rgba(238,233,222,${Math.max(0.06, 0.3 - i * 0.04)})`;
          ctx.lineWidth = 1.1;
          ctx.shadowColor = "transparent";
          ctx.shadowBlur = 0;
        }
        ctx.stroke();
      }
      if (!reduce) raf = requestAnimationFrame(draw);
    };
    draw();

    return () => {
      cancelAnimationFrame(raf);
      observer.disconnect();
      window.removeEventListener("pointermove", onMove);
      audioRef.current?.stop();
      audioRef.current = null;
    };
  }, []);

  const toggleSound = () => {
    if (audioRef.current) {
      audioRef.current.stop();
      audioRef.current = null;
      setSoundOn(false);
    } else {
      audioRef.current = createWaveAudio();
      setSoundOn(true);
    }
  };

  return (
    <div className="hero-wave">
      <canvas ref={canvasRef} aria-hidden="true" />
      <button
        type="button"
        className={`wave-sound${soundOn ? " is-on" : ""}`}
        onClick={toggleSound}
        aria-pressed={soundOn}
      >
        {soundOn ? <Volume2 size={15} /> : <VolumeX size={15} />}
        {soundOn ? "Звук волны включён" : "Включить звук волны"}
      </button>
    </div>
  );
}
