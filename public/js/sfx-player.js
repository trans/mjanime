// sfx-player.js — the browser side of mj's `sfx` tool (classic script; sets window.playSfx).
// Turns a .sfx.json recipe into sound with the Web Audio API. See web/sfx-player.js for the
// ESM version + docs.
function playSfx(ctx, r, startTime) {
  const t = startTime ?? ctx.currentTime, fs = ctx.sampleRate, dur = r.duration ?? 1;
  let src;
  const s = r.source || { type: "noise" };
  if (s.type === "noise") {
    const buf = ctx.createBuffer(1, Math.max(1, Math.floor(fs * Math.max(2, dur))), fs);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    src = ctx.createBufferSource(); src.buffer = buf; src.loop = true;
  } else {
    src = ctx.createOscillator(); src.type = s.wave || "sine";
    src.frequency.setValueAtTime(s.freq ?? 440, t);
    if (s.freqEnd != null) src.frequency.linearRampToValueAtTime(s.freqEnd, t + dur);
  }
  let node = src;
  for (const f of r.filters || []) {
    const bq = ctx.createBiquadFilter(); bq.type = f.type; bq.frequency.value = f.freq;
    if (f.q != null) bq.Q.value = f.q; if (f.gain != null) bq.gain.value = f.gain;
    node.connect(bq); node = bq;
  }
  const wob = ctx.createGain(), lfos = [];
  if (r.wobble && (r.wobble.rates || []).length) {
    wob.gain.value = r.wobble.base ?? 0.7;
    const amt = ctx.createGain(); amt.gain.value = r.wobble.depth ?? 0.2;
    for (const rate of r.wobble.rates) { const l = ctx.createOscillator(); l.frequency.value = rate; l.connect(amt); lfos.push(l); }
    amt.connect(wob.gain);
  } else wob.gain.value = 1;
  node.connect(wob);
  const env = ctx.createGain(), g = r.gain ?? 0.9, a = r.env?.attack ?? 0.01, rel = r.env?.release ?? 0.05;
  env.gain.setValueAtTime(0.0001, t);
  env.gain.linearRampToValueAtTime(g, t + a);
  env.gain.setValueAtTime(g, t + Math.max(a, dur - rel));
  env.gain.linearRampToValueAtTime(0.0001, t + dur);
  wob.connect(env); env.connect(ctx.destination);
  const stopAt = t + dur + 0.05, all = [src, ...lfos];
  all.forEach(n => n.start(t)); all.forEach(n => n.stop(stopAt));
  return { stop(w) { try { all.forEach(n => n.stop(w ?? ctx.currentTime)); } catch (_) {} } };
}
function fetchSfx(url) { return fetch(url).then(r => r.json()); }
window.playSfx = playSfx;
window.fetchSfx = fetchSfx;
