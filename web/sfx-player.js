// sfx-player.js — the browser side of mj's `sfx` tool.
//
// `mj sfx <sound>` analyzes a reference sound and emits a procedural recipe
// (a small JSON object). This generic player turns any such recipe into sound
// with the Web Audio API — no audio files to load, live-tweakable, tiny.
//
// Recipe shape (all fields optional except source):
//   {
//     "duration": 3.0,          // seconds
//     "gain": 0.9,              // 0..1 output level
//     "source": { "type": "noise" }                       // textural (rumble/wind/explosion)
//              | { "type": "osc", "wave": "square",        // tonal (coin/laser/jump)
//                  "freq": 880, "freqEnd": 1320 },         // freqEnd => pitch sweep
//     "filters": [ { "type": "highpass"|"lowpass"|"peaking"|"bandpass",
//                    "freq": 200, "q": 0.7, "gain": 8 } ], // chained biquads
//     "wobble":  { "rates": [3.1, 4.7], "depth": 0.16, "base": 0.66 }, // slow amplitude LFOs
//     "env":     { "attack": 0.45, "release": 1.0 }        // seconds
//   }
//
// Usage:
//   const ctx = new AudioContext();
//   fetchSfx("rumble.sfx.json").then(r => playSfx(ctx, r));
//   // or trigger on an event:  button.onclick = () => playSfx(ctx, coinRecipe);
//
// The filters use Web Audio BiquadFilterNodes, which implement the same RBJ
// "audio EQ cookbook" formulas mj's analyzer used — so what mj fits offline is
// what plays here.

/**
 * Play a procedural SFX recipe. Returns { stop } to cut it short.
 * @param {BaseAudioContext} ctx
 * @param {object} r  a recipe (see shape above)
 * @param {number} [startTime] when to start (defaults to ctx.currentTime)
 */
export function playSfx(ctx, r, startTime) {
  const t = startTime ?? ctx.currentTime;
  const fs = ctx.sampleRate;
  const dur = r.duration ?? 1;

  // ---- source ----
  let src;
  const s = r.source || { type: "noise" };
  if (s.type === "noise") {
    const buf = ctx.createBuffer(1, Math.max(1, Math.floor(fs * Math.max(2, dur))), fs);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    src = ctx.createBufferSource();
    src.buffer = buf;
    src.loop = true;
  } else {
    src = ctx.createOscillator();
    src.type = s.wave || "sine";
    src.frequency.setValueAtTime(s.freq ?? 440, t);
    if (s.freqEnd != null) src.frequency.linearRampToValueAtTime(s.freqEnd, t + dur);
  }

  // ---- filter chain ----
  let node = src;
  for (const f of r.filters || []) {
    const bq = ctx.createBiquadFilter();
    bq.type = f.type;
    bq.frequency.value = f.freq;
    if (f.q != null) bq.Q.value = f.q;
    if (f.gain != null) bq.gain.value = f.gain;
    node.connect(bq);
    node = bq;
  }

  // ---- slow amplitude wobble (LFOs -> gain) ----
  const wob = ctx.createGain();
  const lfos = [];
  if (r.wobble && (r.wobble.rates || []).length) {
    wob.gain.value = r.wobble.base ?? 0.7;
    const amt = ctx.createGain();
    amt.gain.value = r.wobble.depth ?? 0.2;
    for (const rate of r.wobble.rates) {
      const lfo = ctx.createOscillator();
      lfo.frequency.value = rate;
      lfo.connect(amt);
      lfos.push(lfo);
    }
    amt.connect(wob.gain);
  } else {
    wob.gain.value = 1;
  }
  node.connect(wob);

  // ---- amplitude envelope ----
  const env = ctx.createGain();
  const g = r.gain ?? 0.9;
  const a = r.env?.attack ?? 0.01;
  const rel = r.env?.release ?? 0.05;
  env.gain.setValueAtTime(0.0001, t);
  env.gain.linearRampToValueAtTime(g, t + a);
  env.gain.setValueAtTime(g, t + Math.max(a, dur - rel));
  env.gain.linearRampToValueAtTime(0.0001, t + dur);
  wob.connect(env);
  env.connect(ctx.destination);

  // ---- run ----
  const stopAt = t + dur + 0.05;
  const all = [src, ...lfos];
  all.forEach((n) => n.start(t));
  all.forEach((n) => n.stop(stopAt));

  return {
    stop(when) {
      const s2 = when ?? ctx.currentTime;
      try { all.forEach((n) => n.stop(s2)); } catch (_) {}
    },
  };
}

/** Fetch a recipe JSON emitted by `mj sfx`. */
export function fetchSfx(url) {
  return fetch(url).then((r) => r.json());
}

// Also expose on window for plain <script> use (non-module).
if (typeof window !== "undefined") {
  window.playSfx = playSfx;
  window.fetchSfx = fetchSfx;
}
