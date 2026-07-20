// soundbox.js — mj's voice/SFX effect box (classic script; sets window.SoundBox).
// Drop in a TTS clip (or any audio), shape it into a robot / parrot / pirate voice with a
// live Web Audio effect chain, audition by ear, and export the processed WAV.
//
// Chain:  bufferSource(pitch) -> overdrive(waveshaper) -> bandpass(hp->lp)
//         -> ring-mod(dry/wet) -> tremolo -> master -> out
// The same buildChain() runs live (AudioContext) and offline (OfflineAudioContext for export),
// so what you hear is exactly what you download.
(function () {
  // Soft-clip overdrive curve. amount 0 = clean (identity), 1 = heavy.
  function driveCurve(amount) {
    const k = amount * 120, n = 2048, curve = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const x = (i / (n - 1)) * 2 - 1;
      curve[i] = (1 + k) * x / (1 + k * Math.abs(x));
    }
    return curve;
  }

  // Build the effect graph in any BaseAudioContext. Returns {src, master, oscs}.
  function buildChain(ctx, buffer, p) {
    const src = ctx.createBufferSource();
    src.buffer = buffer;
    src.playbackRate.value = p.pitch;      // pitch + formant together (parrot = higher & smaller)

    const shaper = ctx.createWaveShaper();
    shaper.curve = driveCurve(p.drive);
    shaper.oversample = "2x";

    const hp = ctx.createBiquadFilter();
    hp.type = "highpass"; hp.frequency.value = p.hp; hp.Q.value = 0.7;
    const lp = ctx.createBiquadFilter();
    lp.type = "lowpass"; lp.frequency.value = p.lp; lp.Q.value = 0.7;

    // Ring modulator: multiply the signal by a carrier sine. ringGain's base gain is 0 and the
    // carrier drives its .gain param, so ringGain's output = signal * carrier = ring mod. Blend
    // against a dry path for the wet/dry mix.
    const ringIn = ctx.createGain();
    const ringGain = ctx.createGain(); ringGain.gain.value = 0;
    const carrier = ctx.createOscillator(); carrier.type = "sine"; carrier.frequency.value = p.ringFreq;
    const carrierAmt = ctx.createGain(); carrierAmt.gain.value = 1;
    carrier.connect(carrierAmt); carrierAmt.connect(ringGain.gain);
    const wet = ctx.createGain(); wet.gain.value = p.ringMix;
    const dry = ctx.createGain(); dry.gain.value = 1 - p.ringMix;
    const ringSum = ctx.createGain();
    ringIn.connect(ringGain); ringGain.connect(wet); wet.connect(ringSum);
    ringIn.connect(dry); dry.connect(ringSum);

    // Tremolo: LFO wobbles a gain around (1 - depth/2), swinging ±depth/2.
    const trem = ctx.createGain(); trem.gain.value = 1 - p.tremDepth / 2;
    const tlfo = ctx.createOscillator(); tlfo.type = "sine"; tlfo.frequency.value = p.tremRate;
    const tdepth = ctx.createGain(); tdepth.gain.value = p.tremDepth / 2;
    tlfo.connect(tdepth); tdepth.connect(trem.gain);

    const master = ctx.createGain(); master.gain.value = p.gain;

    src.connect(shaper); shaper.connect(hp); hp.connect(lp); lp.connect(ringIn);
    ringSum.connect(trem); trem.connect(master);

    return { src, master, oscs: [carrier, tlfo] };
  }

  // AudioBuffer -> 16-bit PCM WAV Blob.
  function encodeWAV(ab) {
    const nCh = ab.numberOfChannels, sr = ab.sampleRate, n = ab.length;
    const blockAlign = nCh * 2, dataLen = n * blockAlign;
    const buf = new ArrayBuffer(44 + dataLen), view = new DataView(buf);
    const str = (o, s) => { for (let i = 0; i < s.length; i++) view.setUint8(o + i, s.charCodeAt(i)); };
    str(0, "RIFF"); view.setUint32(4, 36 + dataLen, true); str(8, "WAVE");
    str(12, "fmt "); view.setUint32(16, 16, true); view.setUint16(20, 1, true);
    view.setUint16(22, nCh, true); view.setUint32(24, sr, true);
    view.setUint32(28, sr * blockAlign, true); view.setUint16(32, blockAlign, true);
    view.setUint16(34, 16, true); str(36, "data"); view.setUint32(40, dataLen, true);
    const chans = []; for (let c = 0; c < nCh; c++) chans.push(ab.getChannelData(c));
    let off = 44;
    for (let i = 0; i < n; i++) for (let c = 0; c < nCh; c++) {
      const s = Math.max(-1, Math.min(1, chans[c][i]));
      view.setInt16(off, s < 0 ? s * 0x8000 : s * 0x7fff, true); off += 2;
    }
    return new Blob([view], { type: "audio/wav" });
  }

  async function renderOffline(buffer, p) {
    const len = Math.ceil(buffer.duration / p.pitch * buffer.sampleRate) + 4096;
    const octx = new OfflineAudioContext(1, len, buffer.sampleRate);
    const { src, master, oscs } = buildChain(octx, buffer, p);
    master.connect(octx.destination);
    oscs.forEach(o => o.start()); src.start();
    return octx.startRendering();
  }

  window.SoundBox = { buildChain, encodeWAV, renderOffline, driveCurve };
})();
