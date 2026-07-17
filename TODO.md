# mj — TODO

## sfx (audio) refinements
- **Composite sounds need layers.** The recipe is single-source (one noise OR one osc), so it can't
  represent a sound that is several things at once. The bowling "bloop" is attack-transient + tonal bloop
  (descending ~400->140Hz) + fast-fading noise residual — needs a `layers:[...]` extension (recipe = stack
  of voices summed; playSfx just builds N graphs and sums). Proven by hand: data/dunk-layered2.sfx.json.
  Verdict: a reasonable first approximation for complex/stochastic sounds (water is inherently hard);
  captures overall tone, misses nuance. Good enough as a starting point.
- **Transient contaminates the spectral fit.** A sharp broadband onset click makes the fitter read the
  whole sound as noisy + pushes the lowpass edge too high (bright splash) even when the sustained body is
  low/tonal. Fix: detect the onset transient and fit source/band on the sustained TAIL, not the click.
- [x] **Transient / percussive mode** — DONE 2026-07-15. Detect front-loaded sounds via envelope
  temporal centroid → sharp attack + decay + no wobble; tighten body to actual energy so a silent
  lead-in can't inflate the attack. Water dunk now auto-fits a proper hit; rumble stays sustained.
  (Still crude: uses a `**1.5` power decay, not a true exponential; ignores secondary splashes.)
- **Filtered-random wobble** envelope instead of summed sine LFOs — the sines read slightly regular;
  a low-passed random envelope (like the first hand-tuned synth) is more organic.
- **Fit the peaking Q** from the resonant peak's bandwidth instead of the fixed `1.5`.
- **Pitch-sweep detection** for the tonal (osc) branch — fit rising/falling freq from the spectrogram.
  Needs a tonal reference to test (coin / laser / jump).

## image loose ends (explored, never wrapped as tools)
- **`panorama`** tool — wide establishing shots. Easy now: Nano Banana 2 (`google:4@3`) has native
  ultra-wide aspect presets (21:9 `1548×672`, etc.), retiring the old FLUX-dims workaround.
- **`zoom` / `enter`** tool — generative point-and-click scene generator (two-ref recipe:
  subject-crop + wide-scene → a new destination scene). See memory `generative-zoom-pointclick`.

## pixelize
- Prompt exception for text/signage: keep it as straight pixelation, not redrawn letters
  (redrawn lettering reads poorly, esp. at 8-bit). — added 2026-07-14.
- **Tweak / validate the text-exception** — the first pass leans text blockier but isn't a clean win
  (Nano regenerates the whole image each run, so it's not an isolated A/B). Revisit: test on hard cases
  (small/dense text, tiny 8-bit lettering, busy multi-word signs), and consider stronger wording if
  needed. Nano Banana 2 already renders sign text fairly well, so the win shows most on hard cases.

## lip-sync / mouth (ported from siliconcircus 2026-07-16)
- Ported `public/mouth-charter.html` (manual per-frame openness capture) + `tools/align.py` (Viterbi
  retiming: openness curve + audio RMS → forward/reverse/hold path, hub-hops between clips).
- **AI mouth-openness scorer (the mj value-add).** Auto-produce `openness.csv`: human picks the max-open
  anchor frame; AI rates each (sub-sampled) frame's open % vs that anchor → consistent scale, no sort,
  works on stylized/non-human faces where CV landmarks fail. Same CSV contract → drops into align.py.
  Optionally also emit a viseme label per frame (open_pct + viseme in one call). Validate on
  `archive/cattacula-yappy.mp4`. Then wire as `mj mouth` (CLI + bus) + an "AI auto-fill" button in the charter.
