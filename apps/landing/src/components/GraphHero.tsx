import { useEffect, useRef } from "react";

type Kind = "track" | "artist" | "friend" | "genre";

type GraphNode = {
  label: string;
  kind: Kind;
  // Home position in normalized space (-1..1)
  hx: number;
  hy: number;
  x: number;
  y: number;
  phase: number;
  r: number;
};

const NODES: Array<Omit<GraphNode, "x" | "y" | "phase">> = [
  { label: "Nightcall", kind: "track", hx: 0, hy: 0, r: 13 },
  { label: "Kavinsky", kind: "artist", hx: -0.42, hy: -0.38, r: 9 },
  { label: "OutRun", kind: "track", hx: -0.7, hy: 0.06, r: 7 },
  { label: "Synthwave", kind: "genre", hx: 0.46, hy: -0.52, r: 7 },
  { label: "College", kind: "artist", hx: 0.74, hy: -0.12, r: 8 },
  { label: "A Real Hero", kind: "track", hx: 0.6, hy: 0.36, r: 7 },
  { label: "Аня · 87%", kind: "friend", hx: -0.28, hy: 0.58, r: 8 },
  { label: "Миша · 72%", kind: "friend", hx: 0.2, hy: 0.72, r: 8 },
  { label: "Odd Look", kind: "track", hx: -0.86, hy: -0.46, r: 6 },
  { label: "Blend", kind: "genre", hx: -0.02, hy: -0.8, r: 6 },
  { label: "Electric Youth", kind: "artist", hx: 0.9, hy: 0.62, r: 6 },
  { label: "Turbo Killer", kind: "track", hx: -0.66, hy: 0.78, r: 5 }
];

const EDGES: Array<[number, number]> = [
  [0, 1], [0, 3], [0, 4], [0, 5], [0, 6], [0, 7],
  [1, 2], [1, 8], [3, 4], [3, 9], [4, 5], [5, 10],
  [6, 7], [6, 11], [2, 11], [9, 1], [7, 10]
];

const COLORS: Record<Kind, string> = {
  track: "--graph-track",
  artist: "--graph-artist",
  friend: "--graph-friend",
  genre: "--graph-genre"
};

/**
 * Lightweight animated Music Graph for the hero. Canvas 2D, ~12 nodes,
 * paused when off-screen or tab hidden, static frame under reduced motion.
 */
export function GraphHero() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
    const nodes: GraphNode[] = NODES.map((n, i) => ({ ...n, x: n.hx, y: n.hy, phase: i * 1.7 }));
    let width = 0;
    let height = 0;
    let raf = 0;
    let visible = true;
    let pointer: { x: number; y: number } | null = null;
    const start = performance.now();

    const palette = () => {
      const style = getComputedStyle(canvas);
      const read = (name: string) => style.getPropertyValue(name).trim() || "#f05a49";
      return {
        line: read("--graph-line"),
        text: read("--graph-text"),
        track: read(COLORS.track),
        artist: read(COLORS.artist),
        friend: read(COLORS.friend),
        genre: read(COLORS.genre)
      };
    };
    let colors = palette();

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      width = rect.width;
      height = rect.height;
      canvas.width = Math.round(width * dpr);
      canvas.height = Math.round(height * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      colors = palette();
    };

    const project = (n: GraphNode) => {
      const pad = Math.min(width, height) * 0.14;
      return {
        px: width / 2 + n.x * (width / 2 - pad),
        py: height / 2 + n.y * (height / 2 - pad)
      };
    };

    const draw = (t: number) => {
      const time = (t - start) / 1000;
      const animate = !reduce.matches;
      for (const n of nodes) {
        const drift = animate ? 0.035 : 0;
        let tx = n.hx + Math.sin(time * 0.5 + n.phase) * drift;
        let ty = n.hy + Math.cos(time * 0.42 + n.phase * 1.3) * drift;
        if (pointer && animate) {
          const { px, py } = project(n);
          const dx = px - pointer.x;
          const dy = py - pointer.y;
          const dist = Math.hypot(dx, dy);
          if (dist < 120 && dist > 0.1) {
            const push = (1 - dist / 120) * 0.06;
            tx += (dx / dist) * push;
            ty += (dy / dist) * push;
          }
        }
        n.x += (tx - n.x) * 0.08;
        n.y += (ty - n.y) * 0.08;
      }

      ctx.clearRect(0, 0, width, height);
      ctx.lineWidth = 1;
      EDGES.forEach(([a, b], i) => {
        const pa = project(nodes[a]);
        const pb = project(nodes[b]);
        ctx.strokeStyle = colors.line;
        ctx.globalAlpha = 0.55;
        ctx.beginPath();
        ctx.moveTo(pa.px, pa.py);
        ctx.lineTo(pb.px, pb.py);
        ctx.stroke();
        if (animate) {
          // Signal travelling along the edge
          const k = (time * 0.35 + i * 0.27) % 1;
          ctx.globalAlpha = Math.sin(k * Math.PI);
          ctx.fillStyle = colors.track;
          ctx.beginPath();
          ctx.arc(pa.px + (pb.px - pa.px) * k, pa.py + (pb.py - pa.py) * k, 2, 0, Math.PI * 2);
          ctx.fill();
        }
      });
      ctx.globalAlpha = 1;

      const fontSize = width < 480 ? 11 : 12;
      ctx.font = `500 ${fontSize}px Inter, Arial, sans-serif`;
      ctx.textBaseline = "middle";
      nodes.forEach((n, i) => {
        const { px, py } = project(n);
        const fill = colors[n.kind];
        const pulse = animate && i === 0 ? 1 + Math.sin(time * 2.2) * 0.12 : 1;
        if (i === 0) {
          ctx.globalAlpha = 0.18;
          ctx.fillStyle = fill;
          ctx.beginPath();
          ctx.arc(px, py, n.r * 2.6 * pulse, 0, Math.PI * 2);
          ctx.fill();
          ctx.globalAlpha = 1;
        }
        ctx.fillStyle = fill;
        ctx.beginPath();
        ctx.arc(px, py, n.r * pulse, 0, Math.PI * 2);
        ctx.fill();
        if (width >= 360 || n.r >= 7) {
          ctx.fillStyle = colors.text;
          const right = px < width * 0.72;
          ctx.textAlign = right ? "left" : "right";
          ctx.fillText(n.label, px + (right ? n.r + 7 : -(n.r + 7)), py);
        }
      });
    };

    const loop = (t: number) => {
      draw(t);
      if (visible && !reduce.matches && !document.hidden) raf = requestAnimationFrame(loop);
    };
    const restart = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(loop);
    };

    resize();
    restart();

    const ro = new ResizeObserver(() => {
      resize();
      restart();
    });
    ro.observe(canvas);
    const io = new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
      if (visible) restart();
    });
    io.observe(canvas);
    const onMove = (e: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      pointer = { x: e.clientX - rect.left, y: e.clientY - rect.top };
    };
    const onLeave = () => { pointer = null; };
    const onTheme = () => { colors = palette(); restart(); };
    canvas.addEventListener("pointermove", onMove);
    canvas.addEventListener("pointerleave", onLeave);
    document.addEventListener("visibilitychange", restart);
    reduce.addEventListener("change", restart);
    window.addEventListener("resonance-theme", onTheme);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
      io.disconnect();
      canvas.removeEventListener("pointermove", onMove);
      canvas.removeEventListener("pointerleave", onLeave);
      document.removeEventListener("visibilitychange", restart);
      reduce.removeEventListener("change", restart);
      window.removeEventListener("resonance-theme", onTheme);
    };
  }, []);

  return (
    <figure className="graph-hero">
      <canvas
        ref={canvasRef}
        className="graph-hero-canvas"
        role="img"
        aria-label="Анимированный музыкальный граф: трек Nightcall связан с артистами, жанрами, похожими треками и друзьями с процентом совместимости"
      />
      <figcaption className="graph-legend">
        <span><i className="dot dot-track" />Треки</span>
        <span><i className="dot dot-artist" />Артисты</span>
        <span><i className="dot dot-genre" />Жанры и Blend</span>
        <span><i className="dot dot-friend" />Друзья</span>
      </figcaption>
    </figure>
  );
}
