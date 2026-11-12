// Resonance α landing: the living blob, colour taken from covers, and the
// current build read from the same manifest the app checks for updates.
(() => {
  "use strict";

  const SAGE = [180, 201, 164];
  const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;

  const TRACKS = [
    { title: "crush", artist: "2hollis", cover: "crush.jpg" },
    { title: "Выходной", artist: "MONATIK", cover: "vyhodnoy.jpg" },
    { title: "так совпало", artist: "wavescale", cover: "tak-sovpalo.jpg" },
    { title: "Noir", artist: "anoufie", cover: "noir.jpg" },
    { title: "Surround Sound", artist: "JID", cover: "surround-sound.jpg" },
    { title: "Can't Tell Me Nothing", artist: "Kanye West", cover: "cant-tell.jpg" },
  ];
  const SWATCHES = [
    ["Шалфей", "#b4c9a4"],
    ["Песок", "#d8c29e"],
    ["Пудра", "#d9ada4"],
    ["Лаванда", "#b6b0da"],
    ["Небо", "#9fbcd8"],
    ["Кость", "#e4ddcd"],
  ];
  const MOOD = {
    any: { label: "ЛЮБОЕ", bpm: 108, punch: 0.8 },
    active: { label: "БОДРОЕ", bpm: 128, punch: 1 },
    fun: { label: "ВЕСЁЛОЕ", bpm: 118, punch: 0.9 },
    calm: { label: "СПОКОЙНОЕ", bpm: 76, punch: 0.45 },
  };
  const NOVELTY = { familiar: "ЗНАКОМОЕ", mixed: "МИКС", fresh: "НЕЗНАКОМОЕ" };

  // ── Colour ─────────────────────────────────────────

  function rgbToHsl([r, g, b]) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    const l = (max + min) / 2;
    if (max === min) return [0, 0, l];
    const d = max - min;
    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    let h;
    if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    return [h * 60, s, l];
  }

  function hslToRgb(h, s, l) {
    const k = (n) => (n + h / 30) % 12;
    const a = s * Math.min(l, 1 - l);
    const f = (n) => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
    return [f(0) * 255, f(8) * 255, f(4) * 255];
  }

  function rgbToHsv([r, g, b]) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    const d = max - min;
    let h = 0;
    if (d) {
      if (max === r) h = ((g - b) / d) % 6;
      else if (max === g) h = (b - r) / d + 2;
      else h = (r - g) / d + 4;
      h *= 60;
      if (h < 0) h += 360;
    }
    return [h, max ? d / max : 0, max];
  }

  /** Same rule as the app: the loudest hue bucket, softened for a black stage. */
  function pickAccent(rgba) {
    const buckets = 24;
    const weight = new Array(buckets).fill(0);
    const hx = new Array(buckets).fill(0);
    const hy = new Array(buckets).fill(0);
    const sat = new Array(buckets).fill(0);
    for (let i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 128) continue;
      const [h, s, v] = rgbToHsv([rgba[i], rgba[i + 1], rgba[i + 2]]);
      if (s < 0.22 || v < 0.18) continue;
      const w = s * s * (0.4 + v);
      const index = Math.floor((h / 360) * buckets) % buckets;
      weight[index] += w;
      const rad = (h * Math.PI) / 180;
      hx[index] += Math.cos(rad) * w;
      hy[index] += Math.sin(rad) * w;
      sat[index] += s * w;
    }
    let best = -1, bestScore = 0;
    for (let i = 0; i < buckets; i++) {
      const score = weight[i] + 0.5 * weight[(i + 1) % buckets] +
        0.5 * weight[(i - 1 + buckets) % buckets];
      if (score > bestScore) { bestScore = score; best = i; }
    }
    if (best < 0 || bestScore < (rgba.length / 4) * 0.02) return [217, 211, 199];
    let hue = (Math.atan2(hy[best], hx[best]) * 180) / Math.PI;
    if (hue < 0) hue += 360;
    const s = Math.min(0.52, Math.max(0.28, (sat[best] / weight[best]) * 0.6));
    return hslToRgb(hue, s, 0.7);
  }

  /** Deep shade of the accent for text placed on it. */
  function inkOf(rgb) {
    const [h, s] = rgbToHsl(rgb);
    return hslToRgb(h, s * 0.6, 0.14);
  }

  const hex = (rgb) => "#" + rgb.map((v) => Math.round(v).toString(16).padStart(2, "0")).join("");
  const parseHex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const css = (rgb) => `rgb(${rgb.map(Math.round).join(" ")})`;

  // The accent eases towards its target, so the whole page re-tints softly.
  let accent = SAGE.slice();
  let accentTarget = SAGE.slice();
  const root = document.documentElement.style;

  function applyAccent() {
    root.setProperty("--accent", css(accent));
    root.setProperty("--ink", css(inkOf(accent)));
    root.setProperty("--accent-wash", `rgb(${accent.map(Math.round).join(" ")} / 0.12)`);
  }

  function stepAccent(dt) {
    let moving = false;
    for (let i = 0; i < 3; i++) {
      const d = accentTarget[i] - accent[i];
      if (Math.abs(d) > 0.4) moving = true;
      accent[i] += d * Math.min(1, dt * 3.2);
    }
    if (moving) applyAccent();
  }

  function setAccent(rgb, instant) {
    accentTarget = rgb.slice();
    if (instant || reduced) { accent = rgb.slice(); applyAccent(); }
  }

  function readCover(src) {
    return new Promise((resolve) => {
      const img = new Image();
      img.decoding = "async";
      img.onload = () => {
        try {
          const c = document.createElement("canvas");
          c.width = c.height = 40;
          const g = c.getContext("2d", { willReadFrequently: true });
          g.drawImage(img, 0, 0, 40, 40);
          resolve(pickAccent(g.getImageData(0, 0, 40, 40).data));
        } catch {
          resolve(SAGE);
        }
      };
      img.onerror = () => resolve(SAGE);
      img.src = src;
    });
  }

  // ── Sound: a synthetic beat run through the app's envelope follower ──

  const sound = {
    envelope: 0, kick: 0, average: 0, quietFor: 10,
    get active() { return this.quietFor < 1.5; },
    feed(level) {
      const value = level <= 0 ? 0 : Math.min(1, Math.max(0, (20 * Math.log10(level) + 42) / 42));
      if (value > 0.02) this.quietFor = 0;
      this.envelope += (value - this.envelope) * (value > this.envelope ? 0.55 : 0.12);
      const rise = value - this.average;
      if (rise > 0.08) this.kick = Math.max(this.kick, Math.min(1, rise * 3.2));
      this.average += (value - this.average) * 0.08;
    },
    decay(dt) {
      this.kick *= Math.pow(0.002, dt);
      this.quietFor += dt;
    },
  };

  // ── Blob ───────────────────────────────────────────

  const canvas = document.getElementById("blob");
  const ctx = canvas.getContext("2d");
  let width = 0, height = 0, dpr = 1;

  function resize() {
    const box = canvas.getBoundingClientRect();
    dpr = Math.min(2, window.devicePixelRatio || 1);
    width = box.width;
    height = box.height;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function shape(cx, cy, r, t, wobble) {
    const points = 96;
    ctx.beginPath();
    for (let i = 0; i <= points; i++) {
      const a = (i / points) * Math.PI * 2;
      const k = 1 + wobble * (Math.sin(a * 2 + t * 1.3) * 0.55 +
        Math.sin(a * 3 - t * 1.7 + 1.2) * 0.3 +
        Math.sin(a * 5 + t * 2.3 + 0.4) * 0.15);
      const x = cx + Math.cos(a) * r * k;
      const y = cy + Math.sin(a) * r * k * 0.96;
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.closePath();
  }

  const mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
  const rgba = (rgb, a) => `rgb(${rgb.map(Math.round).join(" ")} / ${a})`;

  let label = "Мой\nпоток";
  const fontReady = document.fonts ? document.fonts.load('800 64px "Unbounded"') : Promise.resolve();

  function wrap(text, size, maxWidth) {
    ctx.font = `800 ${size}px Unbounded, system-ui, sans-serif`;
    if ("letterSpacing" in ctx) ctx.letterSpacing = `${-size * 0.045}px`;
    const lines = [];
    for (const para of text.split("\n")) {
      let line = "";
      for (const word of para.split(" ")) {
        const next = line ? line + " " + word : word;
        if (ctx.measureText(next).width <= maxWidth || !line) line = next;
        else { lines.push(line); line = word; }
      }
      lines.push(line);
    }
    const widest = Math.max(...lines.map((l) => ctx.measureText(l).width));
    return { lines, widest };
  }

  function drawLabel(cx, cy, radius) {
    const maxWidth = radius * 1.6;
    let size = Math.min(84, radius * 0.42);
    let fit = wrap(label, size, maxWidth);
    while ((fit.lines.length > 3 || fit.widest > maxWidth ||
      fit.lines.length * size * 0.92 > radius * 1.3) && size > 18) {
      size *= 0.9;
      fit = wrap(label, size, maxWidth);
    }
    ctx.fillStyle = css(inkOf(accent));
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    const lineHeight = size * 0.92;
    const top = cy - ((fit.lines.length - 1) * lineHeight) / 2 + size * 0.04;
    fit.lines.forEach((l, i) => ctx.fillText(l, cx, top + i * lineHeight));
  }

  let time = 0;
  let energy = 0.15;
  let playing = false;

  function paint() {
    ctx.clearRect(0, 0, width, height);
    const cx = width / 2;
    const cy = height / 2;
    const live = sound.active;
    const swell = live ? sound.envelope * 0.07 + sound.kick * 0.09 : 0;
    const base = Math.min(width * 0.42, (height - 80) * 0.36);
    const radius = base * (1 + swell);
    const jolt = live ? sound.kick * 0.14 : 0;
    const e = energy;

    // Halo: a soft wash of the accent behind the mass.
    const halo = ctx.createRadialGradient(cx, cy, radius * 0.4, cx, cy, radius * 1.9);
    halo.addColorStop(0, rgba(accent, Math.min(0.5, 0.1 + e * 0.1 + swell * 0.9)));
    halo.addColorStop(1, rgba(accent, 0));
    ctx.fillStyle = halo;
    ctx.fillRect(0, 0, width, height);

    // Ghost outlines trailing behind the mass.
    ctx.lineWidth = 1.2;
    for (let i = 3; i >= 1; i--) {
      shape(cx, cy, radius * (1 + i * (0.07 + jolt * 0.25)), time - i * 0.22, 0.12 + e * 0.1);
      ctx.strokeStyle = rgba(accent, 0.2 - i * 0.05);
      ctx.stroke();
    }

    shape(cx, cy, radius, time, 0.09 + e * 0.13 + jolt);
    const gx = cx + Math.sin(time * 0.9) * radius * 0.5;
    const gy = cy + (Math.cos(time * 0.6) * 0.5 - 0.2) * radius;
    const fill = ctx.createRadialGradient(gx, gy, 0, gx, gy, radius * 1.9);
    fill.addColorStop(0, css(mix(accent, [255, 255, 255], 0.16)));
    fill.addColorStop(0.6 * 0.55, css(accent));
    fill.addColorStop(1, css(mix(accent, [0, 0, 0], 0.18)));
    ctx.fillStyle = fill;
    ctx.fill();

    drawLabel(cx, cy, radius);
  }

  let beatClock = 0;
  let mood = "any";

  function tick(dt) {
    const target = playing ? 1 : 0.15;
    energy += (target - energy) * Math.min(1, dt * 2.4);
    sound.decay(dt);
    if (playing) {
      const { bpm, punch } = MOOD[mood];
      beatClock += dt * (bpm / 60);
      const phase = beatClock % 1;
      const offbeat = (beatClock * 2) % 1;
      // Kick on the beat, a lighter hat between, a body that drifts.
      const body = 0.18 + 0.06 * Math.sin(beatClock * 0.7);
      const level = body + punch * 0.7 * Math.exp(-phase * 9) + 0.12 * Math.exp(-offbeat * 14);
      sound.feed(level);
    } else {
      sound.feed(0);
    }
    time += dt * (0.35 + energy * 0.9 + sound.kick * 0.8);
  }

  let last = performance.now();
  let visible = true;

  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    stepAccent(dt);
    if (!reduced) tick(dt);
    if (visible) paint();
    requestAnimationFrame(frame);
  }

  new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; })
    .observe(canvas);
  addEventListener("resize", () => { resize(); paint(); });

  // ── Flow demo ──────────────────────────────────────

  const tag = document.getElementById("flow-tag");
  const hint = document.getElementById("flow-hint");
  const artist = document.getElementById("flow-artist");
  const hit = document.getElementById("stage-hit");
  let novelty = "mixed";
  let fromCover = true;
  let fixed = SAGE;
  let current = -1;
  let rotate = 0;
  const accents = TRACKS.map(() => null);

  function updateTag() {
    tag.textContent = playing
      ? `ПОТОК · ${MOOD[mood].label}`
      : `ПОТОК · ${NOVELTY[novelty]}`;
  }

  function show(index) {
    current = index;
    const track = TRACKS[index];
    label = track.title;
    artist.textContent = track.artist;
    if (fromCover && accents[index]) setAccent(accents[index]);
    document.querySelectorAll(".track").forEach((el, i) =>
      el.setAttribute("aria-pressed", String(i === index)));
    if (reduced) paint();
  }

  function play(index) {
    playing = true;
    hit.setAttribute("aria-pressed", "true");
    hint.textContent = "СТОП ×";
    show(index ?? (current + 1) % TRACKS.length);
    updateTag();
    clearInterval(rotate);
    rotate = setInterval(() => show((current + 1) % TRACKS.length), 9000);
  }

  function stop() {
    playing = false;
    clearInterval(rotate);
    hit.setAttribute("aria-pressed", "false");
    hint.textContent = "НАЖМИ НА ФОРМУ";
    label = "Мой\nпоток";
    artist.textContent = "";
    updateTag();
    if (reduced) paint();
  }

  hit.addEventListener("click", () => (playing ? stop() : play()));
  hint.addEventListener("click", () => (playing ? stop() : play()));
  hint.style.cursor = "pointer";

  document.querySelectorAll(".chips").forEach((group) => {
    group.addEventListener("click", (event) => {
      const chip = event.target.closest(".chip");
      if (!chip) return;
      group.querySelectorAll(".chip").forEach((c) => c.classList.toggle("is-on", c === chip));
      if (group.dataset.group === "mood") mood = chip.dataset.value;
      else novelty = chip.dataset.value;
      updateTag();
    });
  });

  // ── Colour section ─────────────────────────────────

  const list = document.getElementById("tracks");
  TRACKS.forEach((track, i) => {
    const li = document.createElement("li");
    li.innerHTML =
      `<button type="button" class="track" aria-pressed="false">` +
      `<img src="/alpha-main/assets/covers/${track.cover}" alt="" width="56" height="56" loading="lazy">` +
      `<span class="track-text"><span class="track-title"></span><span class="track-artist"></span></span>` +
      `<span class="track-dot" aria-hidden="true"></span></button>`;
    li.querySelector(".track-title").textContent = track.title;
    li.querySelector(".track-artist").textContent = track.artist;
    li.querySelector("button").addEventListener("click", () => {
      fromCover = true;
      markSwatch(null);
      play(i);
      if (accents[i]) setAccent(accents[i]);
    });
    list.appendChild(li);
    readCover(`/alpha-main/assets/covers/${track.cover}`).then((rgb) => {
      accents[i] = rgb;
      li.querySelector(".track-dot").style.setProperty("--dot", css(rgb));
      if (current === i && fromCover) setAccent(rgb);
    });
  });

  const swatchBox = document.getElementById("swatches");
  function markSwatch(name) {
    swatchBox.querySelectorAll(".swatch").forEach((s) =>
      s.setAttribute("aria-pressed", String(s.dataset.name === name)));
  }
  SWATCHES.forEach(([name, value]) => {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "swatch";
    b.dataset.name = name;
    b.textContent = name;
    b.style.setProperty("--dot", value);
    b.setAttribute("aria-pressed", "false");
    b.addEventListener("click", () => {
      const same = !fromCover && hex(fixed) === value;
      fromCover = same;
      fixed = parseHex(value);
      markSwatch(same ? null : name);
      setAccent(same && current >= 0 && accents[current] ? accents[current] : fixed);
    });
    swatchBox.appendChild(b);
  });

  // ── Build info from the update manifest ────────────

  const mb = (bytes) => `${Math.round(bytes / 1048576)} МБ`;

  fetch("/downloads/alpha/latest.json", { cache: "no-cache" })
    .then((r) => (r.ok ? r.json() : Promise.reject()))
    .then((release) => {
      if (typeof release.version === "string") {
        document.querySelectorAll("[data-version]").forEach((el) => { el.textContent = release.version; });
      }
      if (typeof release.notes === "string" && release.notes) {
        const notes = document.getElementById("notes");
        notes.textContent = `Новое в этой сборке: ${release.notes}.`;
        notes.hidden = false;
      }
    })
    .catch(() => {});

  ["windows", "ios"].forEach((platform) => {
    fetch(`/downloads/alpha/${platform}`, { method: "HEAD" })
      .then((r) => {
        const size = Number(r.headers.get("content-length"));
        if (!r.ok || !size) return;
        document.querySelectorAll(`[data-size="${platform}"]`).forEach((el) => {
          el.textContent = el.closest(".pill")
            ? `${platform === "ios" ? "IPA" : "ZIP"} · ${mb(size)}`
            : mb(size);
        });
      })
      .catch(() => {});
  });

  // ── Bar ────────────────────────────────────────────

  const bar = document.querySelector(".bar");
  const onScroll = () => bar.classList.toggle("is-scrolled", scrollY > 8);
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  resize();
  applyAccent();
  updateTag();
  fontReady.then(paint, paint);
  requestAnimationFrame(frame);
})();
