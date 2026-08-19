# `mj sfx` — procedural Web Audio SFX from a reference sound

mj's first **audio** tool. Analyze a reference sound and emit a **procedural `.sfx.json` recipe**
that a tiny generic Web Audio player synthesizes in-browser — no audio assets ship, and the sound is
live-tweakable. No API needed (fully local).

```
mj sfx <input.wav|mp3> [out.sfx.json] [preview.wav]
```

- Default output: `<input>.sfx.json` (extension replaced).
- Optional 3rd arg renders an approximation **preview wav** so you can hear the fit.
- Examples: `examples/sfx/dunk.sfx.json`, `examples/sfx/rumble.sfx.json`.

## Architecture

- The DSP analyzer is **Python** (`src/engine/sfx_fit.py`, numpy/scipy/ffmpeg), **embedded into the
  binary** at compile time (`{{ read_file(...) }}`) and written to a temp file on first use — so `mj`
  ships as a single artifact.
- The Crystal side (`MJ::Sfx.fit`) just shells out to `python3 <script> <input> [--preview …]` and
  parses the JSON.
- **Runtime deps:** `python3` (with numpy, scipy) and `ffmpeg` on PATH. (Missing → a clear error.)

## Recipe shape

```jsonc
{
  "duration": ..., "gain": ...,
  "source": { "type": "noise" | "osc", ... },        // noise = textural (rumble/wind); osc = tonal (coin/laser)
  "filters": [ { "type": "highpass|lowpass|peaking", "freq": ..., "q": ..., "gain": ... } ],  // chained biquads
  "wobble": { "rates": [...], "depth": ..., "base": ... },
  "env": { "attack": ..., "release": ... }
}
```

The browser player `playSfx(ctx, recipe)` (~30 lines) is what the game ships — **not yet saved in the
repo** (candidate home: `web/sfx-player.js`).

## Auto-fit (every param derived, no hand-tuning)

- **Band edges** = 5% / 95% cumulative-energy of the spectrum.
- **Resonant peak** + prominence → peaking `freq`/`gain` (Q is a fixed 1.5 for now).
- **Spectral flatness** → noise-vs-tonal source choice.
- **Rolloff slope** → number of lowpass stages (2nd-order biquads stacked for a steeper skirt).
- **Envelope** rise/tail → `attack`/`release`; modulation spectrum (1–12 Hz) → `wobble` rates/depth.
- **Body** = longest above-threshold run after gap-closing, so a transient onset doesn't inflate the
  fit. A percussive/front-loaded sound auto-fits a sharp attack + decay (envelope temporal centroid).

## Honest gaps

- Composite sounds (attack transient + tonal body + noise residual at once) need a `layers:[…]`
  recipe extension — the recipe is single-source today (proven by hand: `data/dunk-layered2.sfx.json`).
- Wobble uses summed sine LFOs (slightly regular) — a filtered-random envelope reads more organic.
- Peaking Q is fixed 1.5 (could be fit from the peak's bandwidth).
- The osc branch has no pitch-sweep detection yet (needs a tonal reference — coin/laser/jump — to
  test). Full list: `TODO.md`.

Also available as the **`sfx` bus tool** (see [bus](bus.md)). Related lesson:
[soundbox / TTS](bus.md#soundbox--tts).

---
Related: [bus](bus.md) · `TODO.md`
