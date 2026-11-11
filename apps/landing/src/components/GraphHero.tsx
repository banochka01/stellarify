import { useEffect, useRef } from "react";

type Kind = "track" | "artist" | "friend" | "genre";
type Side = "right" | "left" | "bottom" | "top";
type Rect = { x: number; y: number; w: number; h: number };

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
  /** Where the label sits; null when there is no room for it. */
  side: Side | null;
  labelWidth: number;
};

const NODES: Array<Pick<GraphNode, "label" | "kind" | "hx" | "hy" | "r">> = [
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

const LABEL_GAP = 7;
const LABEL_PAD = 7;

const overlaps = (a: Rect, b: Rect, margin: number) =>
  a.x < b.x + b.w + margin && a.x + a.w + margin > b.x && a.y < b.y + b.h + margin && a.y + a.h + margin > b.y;

/**
 * Lightweight animated Music Graph for the hero. Canvas 2D, ~12 nodes,
 * paused when off-screen or tab hidden, static frame under reduced motion.
 * Hovering a node lights up its connections.
 */
export function GraphHero() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
    const nodes: GraphNode[] = NODES.map((n, i) => ({ ...n, x: n.hx, y: n.hy, phase: i * 1.7, side: null, labelWidth: 0 }));
    let width = 0;
    let height = 0;
    let scale = 1;
    let fontSize = 12;
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
        labelBg: read("--graph-label-bg"),
        track: read(COLORS.track),
        artist: read(COLORS.artist),
        friend: read(COLORS.friend),
        genre: read(COLORS.genre)
      };
    };
    let colors = palette();

    // The legend sits over the bottom edge of the canvas, so the graph keeps clear of it.
    const legendSpace = () => (width < 480 ? 46 : 52);

    const place = (x: number, y: number) => {
      const pad = Math.max(26, Math.min(width, height) * 0.1);
      const bottom = height - legendSpace() - pad * 0.4;
      const cy = (pad + bottom) / 2;
      return {
        px: width / 2 + x * (width / 2 - pad),
        py: cy + y * ((bottom - pad) / 2)
      };
    };
    const project = (n: GraphNode) => place(n.x, n.y);

    const labelRect = (n: GraphNode, side: Side, px: number, py: number): Rect => {
      const r = n.r * scale;
      const w = n.labelWidth + LABEL_PAD * 2;
      const h = fontSize + 10;
      if (side === "right") return { x: px + r + LABEL_GAP, y: py - h / 2, w, h };
      if (side === "left") return { x: px - r - LABEL_GAP - w, y: py - h / 2, w, h };
      if (side === "bottom") return { x: px - w / 2, y: py + r + LABEL_GAP, w, h };
      return { x: px - w / 2, y: py - r - LABEL_GAP - h, w, h };
    };

    /** Picks a side for every label once per size, so text never collides or leaves the card. */
    const layoutLabels = () => {
      ctx.font = `500 ${fontSize}px Inter, Arial, sans-serif`;
      const homes = nodes.map((n) => place(n.hx, n.hy));
      const dots: Rect[] = nodes.map((n, i) => {
        const r = n.r * scale + 3;
        return { x: homes[i].px - r, y: homes[i].py - r, w: r * 2, h: r * 2 };
      });
      const placed: Rect[] = [];
      const limitBottom = height - legendSpace();
      // Bigger nodes choose first; the smallest ones lose their label when space runs out.
      const order = nodes.map((_, i) => i).sort((a, b) => nodes[b].r - nodes[a].r);
      for (const i of order) {
        const n = nodes[i];
        n.labelWidth = ctx.measureText(n.label).width;
        const { px, py } = homes[i];
        const sides: Side[] = n.hx > 0.55 ? ["left", "right", "bottom", "top"] : ["right", "left", "bottom", "top"];
        n.side = null;
        for (const side of sides) {
          const rect = labelRect(n, side, px, py);
          const inside = rect.x >= 6 && rect.x + rect.w <= width - 6 && rect.y >= 6 && rect.y + rect.h <= limitBottom;
          if (!inside) continue;
          if (placed.some((other) => overlaps(rect, other, 5))) continue;
          if (dots.some((dot, j) => j !== i && overlaps(rect, dot, 2))) continue;
          n.side = side;
          placed.push(rect);
          break;
        }
      }
    };

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      width = rect.width;
      height = rect.height;
      scale = Math.min(1.35, Math.max(0.85, width / 560));
      fontSize = width < 480 ? 11 : width > 640 ? 13 : 12;
      canvas.width = Math.round(width * dpr);
      canvas.height = Math.round(height * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      colors = palette();
      layoutLabels();
    };

    const draw = (t: number) => {
      const time = (t - start) / 1000;
      const animate = !reduce.matches;
      for (const n of nodes) {
        const drift = animate ? 0.03 : 0;
        let tx = n.hx + Math.sin(time * 0.5 + n.phase) * drift;
        let ty = n.hy + Math.cos(time * 0.42 + n.phase * 1.3) * drift;
        if (pointer && animate) {
          const { px, py } = project(n);
          const dx = px - pointer.x;
          const dy = py - pointer.y;
          const dist = Math.hypot(dx, dy);
          if (dist < 120 && dist > 36) {
            const push = (1 - dist / 120) * 0.04;
            tx += (dx / dist) * push;
            ty += (dy / dist) * push;
          }
        }
        n.x += (tx - n.x) * 0.08;
        n.y += (ty - n.y) * 0.08;
      }

      const points = nodes.map(project);
      let hovered = -1;
      if (pointer) {
        let best = 34;
        points.forEach((p, i) => {
          const dist = Math.hypot(p.px - pointer!.x, p.py - pointer!.y);
          if (dist < best) {
            best = dist;
            hovered = i;
          }
        });
      }
      const linked = new Set<number>();
      if (hovered >= 0) {
        linked.add(hovered);
        for (const [a, b] of EDGES) {
          if (a === hovered) linked.add(b);
          if (b === hovered) linked.add(a);
        }
      }
      canvas.style.cursor = hovered >= 0 ? "pointer" : "";

      ctx.clearRect(0, 0, width, height);
      EDGES.forEach(([a, b], i) => {
        const pa = points[a];
        const pb = points[b];
        const lit = hovered >= 0 && (a === hovered || b === hovered);
        ctx.strokeStyle = lit ? colors.track : colors.line;
        ctx.lineWidth = lit ? 1.6 : 1;
        ctx.globalAlpha = hovered < 0 ? 0.6 : lit ? 0.9 : 0.25;
        ctx.beginPath();
        ctx.moveTo(pa.px, pa.py);
        ctx.lineTo(pb.px, pb.py);
        ctx.stroke();
        if (animate && (hovered < 0 || lit)) {
          // Signal travelling along the edge
          const k = (time * 0.35 + i * 0.27) % 1;
          ctx.globalAlpha = Math.sin(k * Math.PI);
          ctx.fillStyle = colors.track;
          ctx.beginPath();
          ctx.arc(pa.px + (pb.px - pa.px) * k, pa.py + (pb.py - pa.py) * k, 2 * scale, 0, Math.PI * 2);
          ctx.fill();
        }
      });
      ctx.globalAlpha = 1;

      nodes.forEach((n, i) => {
        const { px, py } = points[i];
        const fill = colors[n.kind];
        const r = n.r * scale;
        const dim = hovered >= 0 && !linked.has(i);
        const pulse = animate && i === 0 ? 1 + Math.sin(time * 2.2) * 0.1 : 1;
        if (i === 0 || i === hovered) {
          ctx.globalAlpha = dim ? 0.08 : 0.18;
          ctx.fillStyle = fill;
          ctx.beginPath();
          ctx.arc(px, py, r * (i === 0 ? 2.6 : 2.1) * pulse, 0, Math.PI * 2);
          ctx.fill();
        }
        ctx.globalAlpha = dim ? 0.35 : 1;
        ctx.fillStyle = fill;
        ctx.beginPath();
        ctx.arc(px, py, r * pulse, 0, Math.PI * 2);
        ctx.fill();
      });

      // Labels in a separate pass on an opaque pill so edges never cross the text.
      ctx.font = `500 ${fontSize}px Inter, Arial, sans-serif`;
      ctx.textBaseline = "middle";
      ctx.textAlign = "left";
      nodes.forEach((n, i) => {
        if (!n.side) return;
        const { px, py } = points[i];
        const rect = labelRect(n, n.side, px, py);
        ctx.globalAlpha = hovered >= 0 && !linked.has(i) ? 0.4 : 1;
        ctx.fillStyle = colors.labelBg;
        ctx.beginPath();
        ctx.roundRect(rect.x, rect.y, rect.w, rect.h, rect.h / 2);
        ctx.fill();
        ctx.fillStyle = colors.text;
        ctx.fillText(n.label, rect.x + LABEL_PAD, rect.y + rect.h / 2 + 0.5);
      });
      ctx.globalAlpha = 1;
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
      if (reduce.matches) restart();
    };
    const onLeave = () => {
      pointer = null;
      if (reduce.matches) restart();
    };
    const onTheme = () => { colors = palette(); restart(); };
    // Webfonts change text metrics, so the label layout is measured again once they arrive.
    const onFonts = () => { layoutLabels(); restart(); };
    canvas.addEventListener("pointermove", onMove);
    canvas.addEventListener("pointerleave", onLeave);
    document.addEventListener("visibilitychange", restart);
    reduce.addEventListener("change", restart);
    window.addEventListener("resonance-theme", onTheme);
    void document.fonts?.ready.then(onFonts);

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
