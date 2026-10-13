# mj — TODO

## arcana bus (`mj:camera`, `mj:voice`)
- **`shoot_batch`** — one call, a list of shots, each with a caller-supplied `id`; each result carries
  its own `id` and `status` so one refusal doesn't fail the rest. Asked for by `@overlore`
  (2026-10-12), designed, not built. The lanes already give it per-pool concurrency for free; what it
  needs deciding is whether results stream back as they land or arrive as one reply at the end.
- **A workflow endpoint (on the radar, 2026-10-13, Thomas).** Submit a multi-step job, get an id back
  at once, learn about each step as it finishes. The gap it fills is **asynchronous submission**, not
  pipelines as such — `prop`, `base`, `decorate`, `pixelize` and `sfx` are already on the bus as single
  tools. What doesn't fit synchronous request/reply: Gemini batch (~2 min floor however few images),
  `prop` (several provider calls deep), `base`→`decorate` (two stages with an intermediate nobody but
  mj should hold). `shoot_batch` is the smallest instance of the same shape — build that first and see
  whether it generalises, rather than designing a step engine before we know if steps need branching,
  per-step retry or shared intermediates. Two open questions either way:
  - **Where intermediates live.** Bus services are filesystem-isolated, so stage two can't be handed a
    path. Either mj holds them in memory for the job's life, or they go to R2 and steps pass URLs —
    which argues for finishing the R2 move first.
  - **Whether per-step notification is even available.** Gemini's batch goes straight from `RUNNING` to
    `SUCCEEDED` with no partial completion, so for that lane the honest answer may be one message when
    the whole lot lands.
- **`mj:voice` concurrency** — unmeasured; needs the ElevenLabs plan tier and a key on this host.
- **Reference-order A/B** — whether providers weight the first reference most. The claim was removed
  from the schema as unverified; it stays unverified until measured.
- **URL pass-through to providers** — all three accept image URLs and Google is verified to fetch them,
  so a public R2 link could skip a download-and-reupload per shot. Needs the transport interface to
  carry "bytes or URL". See the note in `src/arcana/fetch_reference.cr` for why we always fetch today
  (a loopback URL is unroutable from a provider's servers).

## secrets / deploy
- **Retiring the repo `.env` is blocked on a fish export format.** `@cyclops` settled the four open
  questions (2026-10-13): `local` secrets are delivered by `cyclops-env export mj local > file`
  redirect (an ssh-less `push` is a wishlist item, not a gap); `production`/`local` are the only
  environments, which mj already matches; and `EnvironmentFile` at mode 600 stays the standard —
  `LoadCredential` is to be one hardening pass across every service, so mj is to be left alone.
  The one thing still missing is interactive-shell use: `--format bash` emits `export KEY=value`
  and works under `eval` today, but this shell is fish, so a hand-run `./bin/mj` still needs the
  bash `.env` that CLAUDE.md tells you to source. `@cyclops` has queued a native `fish` format
  (`set -x KEY value`) behind an overlore push and will ping when it lands; until then the `.env`
  has to stay. The conventions are authoritative at
  `~/Projects/cyclops/.ai/memory/cyclops-env-conventions.md` — read that, not this.
- The repo `.env` is mode 644. Everything else in the chain is 600. Worth tightening, but it is
  Thomas's file.

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

## cell animation / compositing
- **UV region editor** — port the in-canvas region tool into mj's web UI. Define a box/ellipse/(polygon)
  on an image by hand and read back normalized `{u,v,w/rx,h/ry}` numbers to paste into code — same UV
  works at any canvas size, in editor and renderer alike. Design doc copied to `notes/uv-region-editor.md`
  (from siliconcircus funhouse). Two immediate mj fits: (a) mark a **prop cutout box** / relight-mask
  region, and (b) the **per-frame `(dx,dy)` alignment offset** that kills the frame-drift shimmer when we
  swap whole AI-rendered frames — the same drift problem behind the mouth/lip-sync + connect-seamstress
  work. Self-contained component: `<canvas>` + cover-fit transform + region list + pointer/wheel handlers
  + live readout + JSON in/out. Endgame it points at: transparent cutout of just the moving part over a
  static base (no mask, no offsets) — the editor is the good-enough-now way to find where the cutout sits.
