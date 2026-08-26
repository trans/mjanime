// mj · cyclochroma — exported player. Recipe baked in below.
// image: test-cave.png   audio: test-beat.wav
//
//   import { mount } from './cyclochroma.js';
//   mount(canvas, { image: 'test-cave.png', audio: 'test-beat.wav' }).start();
//
// All four fields are included — switch at runtime with
//   rig.setRecipe({ mode: 'radial' })

// mj · cyclochroma — portable player
//
// Key a colour out of an image and render a music-reactive colour field through the
// resulting transparency. This is the SAME module the /cyclochroma studio page runs,
// so an exported recipe plays back exactly as it was tuned.
//
//   import { mount } from "./cyclochroma.js";
//   const rig = mount(canvas, { image: "cave.png", audio: "track.mp3" });
//   await rig.start();
//
// With no audio the field still cycles on time alone. Pass `analyser` instead of
// `audio` to share an AnalyserNode you already have in your own graph.

// __RECIPE_START__
export const RECIPE = {
  "key": [
    254,
    43,
    251
  ],
  "low": 10,
  "high": 70,
  "feather": 2,
  "fade": 100,
  "despill": true,
  "holesOnly": true,
  "mode": "spectrum",
  "speed": 40,
  "react": 100,
  "sat": 85,
  "bright": 60,
  "spread": 120
};
// __RECIPE_END__

export const FIELDS = ["cycle", "spectrum", "radial", "plasma"];

// ---- keying ---------------------------------------------------------------

/** Mean colour of the four corner patches — a render's backdrop is never the exact
 *  colour that was asked for, so sampling beats trusting a swatch. */
export function sampleCorners(img, W, H) {
  const c = document.createElement("canvas");
  c.width = W; c.height = H;
  const g = c.getContext("2d", { willReadFrequently: true });
  g.drawImage(img, 0, 0, W, H);
  const s = Math.max(2, Math.min(W, H) >> 5);
  let r = 0, gg = 0, b = 0, n = 0;
  for (const [sx, sy] of [[0, 0], [W - s, 0], [0, H - s], [W - s, H - s]]) {
    const d = g.getImageData(sx, sy, s, s).data;
    for (let i = 0; i < d.length; i += 4) { r += d[i]; gg += d[i + 1]; b += d[i + 2]; n++; }
  }
  return [Math.round(r / n), Math.round(gg / n), Math.round(b / n)];
}

/** Distance-from-key alpha ramp with generic despill, then an optional feather blur.
 *  Mirrors mj's Crystal prop keyer so studio and runtime agree. */
export function keyImage(img, r, W, H) {
  const work = document.createElement("canvas");
  work.width = W; work.height = H;
  const w = work.getContext("2d", { willReadFrequently: true });
  w.drawImage(img, 0, 0, W, H);
  const id = w.getImageData(0, 0, W, H), d = id.data;

  const [kr, kg, kb] = r.key || sampleCorners(img, W, H);
  const lo = r.low, hi = Math.max(r.low + 1, r.high), span = hi - lo;
  const gamma = 100 / r.fade;

  // key chroma direction — lets one despill work for any key colour
  const km = (kr + kg + kb) / 3;
  let dr = kr - km, dg = kg - km, db = kb - km;
  const dn = Math.hypot(dr, dg, db) || 1;
  dr /= dn; dg /= dn; db /= dn;

  for (let i = 0; i < d.length; i += 4) {
    const pr = d[i], pg = d[i + 1], pb = d[i + 2];
    const dist = Math.hypot(pr - kr, pg - kg, pb - kb);
    let a = dist <= lo ? 0 : dist >= hi ? 1 : (dist - lo) / span;
    if (a > 0 && a < 1) a = Math.pow(a, gamma);
    if (a < 1 && r.despill) {
      const pm = (pr + pg + pb) / 3;
      const proj = (pr - pm) * dr + (pg - pm) * dg + (pb - pm) * db;
      if (proj > 0) {
        const k = proj * (1 - a);
        d[i]     = Math.max(0, Math.min(255, pr - k * dr));
        d[i + 1] = Math.max(0, Math.min(255, pg - k * dg));
        d[i + 2] = Math.max(0, Math.min(255, pb - k * db));
      }
    }
    d[i + 3] = Math.round(a * 255);
  }
  w.putImageData(id, 0, 0);

  if (r.feather > 0) {
    const soft = document.createElement("canvas");
    soft.width = W; soft.height = H;
    const s = soft.getContext("2d");
    s.filter = `blur(${r.feather}px)`;
    s.drawImage(work, 0, 0);
    return soft;
  }
  return work;
}

/** White where an ENCLOSED transparent region is, clear elsewhere.
 *  Flood-fills from the border through anything not fully opaque — a feathered
 *  silhouette has a partial-alpha fringe, and counting that fringe as "window"
 *  lights it as a halo around the subject. */
export function buildHoleMask(srcCv, W, H) {
  const s = srcCv.getContext("2d", { willReadFrequently: true });
  const d = s.getImageData(0, 0, W, H).data;
  const seen = new Uint8Array(W * H);
  const stack = [];
  const push = (x, y) => {
    if (x < 0 || y < 0 || x >= W || y >= H) return;
    const p = y * W + x;
    if (seen[p] || d[p * 4 + 3] >= 250) return;
    seen[p] = 1; stack.push(p);
  };
  for (let x = 0; x < W; x++) { push(x, 0); push(x, H - 1); }
  for (let y = 0; y < H; y++) { push(0, y); push(W - 1, y); }
  while (stack.length) {
    const p = stack.pop(), x = p % W, y = (p - x) / W;
    push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1);
  }
  const mask = document.createElement("canvas");
  mask.width = W; mask.height = H;
  const m = mask.getContext("2d");
  const mid = m.createImageData(W, H), md = mid.data;
  for (let p = 0; p < W * H; p++) {
    if (seen[p]) continue;
    const i = p * 4, a = d[i + 3];
    if (a >= 250) continue;
    md[i] = md[i + 1] = md[i + 2] = 255;
    md[i + 3] = 255 - a;
  }
  m.putImageData(mid, 0, 0);
  return mask;
}

// ---- audio ----------------------------------------------------------------

export const SILENT = { bass: 0, mid: 0, treble: 0, level: 0 };

/** Three bands plus a weighted overall level, all 0..1. */
export function analyse(analyser, freq) {
  if (!analyser) return SILENT;
  analyser.getByteFrequencyData(freq);
  const n = freq.length;
  const avg = (a, b) => {
    let s = 0; const from = Math.floor(n * a), to = Math.floor(n * b);
    for (let i = from; i < to; i++) s += freq[i];
    return s / Math.max(1, to - from) / 255;
  };
  const bass = avg(0, 0.06), mid = avg(0.06, 0.35), treble = avg(0.35, 1);
  return { bass, mid, treble, level: (bass * 2 + mid + treble) / 4 };
}

// ---- the fields -----------------------------------------------------------

export function drawField(g, tms, b, W, H, r, freq) {
  const t = tms / 1000;
  const react = r.react / 100;
  const hue = (t * r.speed + b.bass * 120 * react) % 360;
  const sat = r.sat;
  const lum = Math.min(96, r.bright * (1 + b.level * 1.6 * react));

  if (r.mode === "spectrum") {
    const bars = 64, bw = W / bars;
    g.fillStyle = `hsl(${hue} ${sat}% ${lum * 0.25}%)`;
    g.fillRect(0, 0, W, H);
    for (let i = 0; i < bars; i++) {
      const v = freq ? freq[Math.floor(i / bars * freq.length * 0.7)] / 255
                     : 0.25 + 0.25 * Math.sin(t * 2 + i * 0.3);
      const h = (hue + i / bars * r.spread) % 360;
      g.fillStyle = `hsl(${h} ${sat}% ${Math.min(96, lum * (0.5 + v))}%)`;
      g.fillRect(i * bw, H * (1 - v), bw + 1, H * v);
    }
    return;
  }

  if (r.mode === "radial") {
    const cx = W / 2, cy = H / 2, R = Math.hypot(cx, cy);
    const grad = g.createRadialGradient(cx, cy, 0, cx, cy, R);
    const rings = 6;
    for (let i = 0; i <= rings; i++) {
      const p = i / rings;
      const pulse = 1 + Math.sin(t * 3 - p * 6) * 0.35 * b.level * react;
      grad.addColorStop(p, `hsl(${(hue + p * r.spread) % 360} ${sat}% ${Math.min(96, lum * pulse)}%)`);
    }
    g.fillStyle = grad; g.fillRect(0, 0, W, H);
    return;
  }

  if (r.mode === "plasma") {
    const sweep = t * (0.15 + b.mid * react * 0.5);
    const x1 = W * (0.5 + 0.5 * Math.cos(sweep)), y1 = H * (0.5 + 0.5 * Math.sin(sweep * 1.3));
    const grad = g.createLinearGradient(x1, y1, W - x1, H - y1);
    grad.addColorStop(0,   `hsl(${hue} ${sat}% ${lum}%)`);
    grad.addColorStop(0.5, `hsl(${(hue + r.spread / 2) % 360} ${sat}% ${Math.min(96, lum * 1.25)}%)`);
    grad.addColorStop(1,   `hsl(${(hue + r.spread) % 360} ${sat}% ${lum}%)`);
    g.fillStyle = grad; g.fillRect(0, 0, W, H);
    return;
  }

  // cycle — one hue filling the window
  g.fillStyle = `hsl(${hue} ${sat}% ${lum}%)`;
  g.fillRect(0, 0, W, H);
}

// ---- player ---------------------------------------------------------------

const loadImage = srcOrEl => (srcOrEl instanceof HTMLImageElement && srcOrEl.complete)
  ? Promise.resolve(srcOrEl)
  : new Promise((res, rej) => {
      const im = srcOrEl instanceof HTMLImageElement ? srcOrEl : new Image();
      im.crossOrigin = "anonymous";
      im.onload = () => res(im); im.onerror = rej;
      if (!(srcOrEl instanceof HTMLImageElement)) im.src = srcOrEl;
    });

/**
 * mount(canvas, opts) -> { start, stop, setRecipe, recipe, destroy }
 *
 *   canvas          where to draw; sized to the image unless `fit` is given
 *   opts.image      URL or HTMLImageElement (raw or already-keyed)
 *   opts.audio      URL, HTMLAudioElement or AudioBuffer — optional
 *   opts.analyser   an AnalyserNode you already own — takes precedence over audio
 *   opts.recipe     overrides merged over RECIPE
 *   opts.loop       loop the audio (default true)
 *   opts.maxSize    cap the working resolution (default 1280)
 */
export function mount(canvas, opts = {}) {
  const r = { ...RECIPE, ...(opts.recipe || {}) };
  const ctx = canvas.getContext("2d");
  let W = 0, H = 0, keyed = null, holeMask = null, fieldCv = null;
  let actx = null, node = null, analyser = opts.analyser || null, freq = null;
  let raf = 0, t0 = 0, running = false, ready = null;

  if (analyser) freq = new Uint8Array(analyser.frequencyBinCount);

  function rekey(img) {
    keyed = keyImage(img, r, W, H);
    holeMask = r.holesOnly ? buildHoleMask(keyed, W, H) : null;
  }

  function frame(tms) {
    if (!keyed) return;
    const b = analyse(analyser, freq);
    ctx.clearRect(0, 0, W, H);
    if (holeMask) {
      if (!fieldCv || fieldCv.width !== W) {
        fieldCv = document.createElement("canvas"); fieldCv.width = W; fieldCv.height = H;
      }
      const fg = fieldCv.getContext("2d");
      fg.globalCompositeOperation = "source-over";
      fg.clearRect(0, 0, W, H);
      drawField(fg, tms - t0, b, W, H, r, freq);
      fg.globalCompositeOperation = "destination-in";
      fg.drawImage(holeMask, 0, 0);
      ctx.drawImage(fieldCv, 0, 0);
    } else {
      drawField(ctx, tms - t0, b, W, H, r, freq);
    }
    ctx.drawImage(keyed, 0, 0);
  }

  function loop(tms) {
    if (!running) return;
    frame(tms);
    raf = requestAnimationFrame(loop);
  }

  async function prepare() {
    const img = await loadImage(opts.image);
    const cap = opts.maxSize || 1280;
    const sc = Math.min(1, cap / Math.max(img.naturalWidth, img.naturalHeight));
    W = canvas.width  = Math.round(img.naturalWidth  * sc);
    H = canvas.height = Math.round(img.naturalHeight * sc);
    rekey(img);
    frame(performance.now());
    return img;
  }

  async function startAudio() {
    if (analyser || !opts.audio) return;
    actx = new (window.AudioContext || window.webkitAudioContext)();
    // Fire-and-forget: outside a user gesture resume() can stay pending indefinitely
    // rather than rejecting, and awaiting it would hang start(). The graph is built
    // either way; it simply reads silence until the context is allowed to run.
    actx.resume().catch(() => {});
    analyser = actx.createAnalyser();
    analyser.fftSize = 2048;
    analyser.smoothingTimeConstant = 0.75;
    freq = new Uint8Array(analyser.frequencyBinCount);
    if (opts.audio instanceof HTMLMediaElement) {
      node = actx.createMediaElementSource(opts.audio);
      opts.audio.loop = opts.loop !== false;
      await opts.audio.play();
    } else {
      const bufr = opts.audio instanceof AudioBuffer
        ? opts.audio
        : await actx.decodeAudioData(await (await fetch(opts.audio)).arrayBuffer());
      node = actx.createBufferSource();
      node.buffer = bufr;
      node.loop = opts.loop !== false;
      node.start();
    }
    node.connect(analyser);
    analyser.connect(actx.destination);
  }

  const api = {
    recipe: r,
    /** Key and draw a single still frame — no audio, no loop. */
    async prime() {
      ready ||= prepare();
      await ready;
      return api;
    },
    /** Begin rendering, and bring the audio up alongside it.
     *  The visuals start FIRST and audio failure never blocks them: browsers refuse to
     *  resume an AudioContext outside a user gesture, and a player that freezes its
     *  picture waiting for that is worse than one that cycles silently. Call from a
     *  click if you want sound on the first try; otherwise call start() again later. */
    async start() {
      ready ||= prepare();
      await ready;
      if (!running) {
        running = true; t0 = performance.now();
        raf = requestAnimationFrame(loop);
      }
      try { await startAudio(); }
      catch (e) { api.audioError = e; }
      return api;
    },
    stop() {
      running = false; cancelAnimationFrame(raf);
      try { node && (node.stop ? node.stop() : node.disconnect()); } catch (_) {}
      node = null;
      return api;
    },
    /** Retune live. Key-affecting changes trigger a re-key; field changes are free. */
    async setRecipe(patch) {
      const rekeys = ["key", "low", "high", "feather", "fade", "despill", "holesOnly"];
      const needs = Object.keys(patch).some(k => rekeys.includes(k));
      Object.assign(r, patch);
      if (needs && ready) rekey(await ready);
      if (!running) frame(performance.now());
      return api;
    },
    destroy() {
      api.stop();
      try { actx && actx.close(); } catch (_) {}
      actx = null; analyser = opts.analyser || null; keyed = holeMask = fieldCv = null;
    },
  };
  return api;
}
