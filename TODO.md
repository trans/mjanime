# mj — TODO

## sfx (audio) refinements
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
