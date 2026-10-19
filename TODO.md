# mj — TODO

## arcana bus (`mj:camera`, `mj:voice`)
- **`shoot_batch`** — one call, a list of shots, each with a caller-supplied `id`; each result carries
  its own `id` and `status` so one refusal doesn't fail the rest. Asked for by `@overlore`
  (2026-10-11), mostly because shots were being drawn one at a time; concurrency fixed that the same
  day (`c7181a7`, lanes in `34b3765`), and **`@overlore` parked it** the same day, until they build a
  "can wait" lane for drawing rooms ahead. Not built. As a plain envelope over concurrent `shoot`s it
  adds little; what would give it a reason to exist is **Google's batch endpoint**
  (`batchGenerateContent`): half the rate, every image model supports it, ~2 min floor however few
  images, nothing uses it yet (`src/arcana/cameras.cr`, `google_direct.cr`). A per-shot "can wait"
  flag routes there; the player's own picture still goes now. Still to decide: whether results stream
  back as they land or arrive as one reply at the end.
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
- **Revisit: `view_words` as a bus tool** (Thomas, 2026-10-14: not yet). DataDungeon now owns turning
  `view` and `light` into words; mj's `src/arcana/view.cr` was handed to them 2026-10-14
  (`.ai/mail/sent/*-@datadungeon--view-words.md`), and is in DataDungeon 0.14 as
  `ViewWords.view`/`ViewWords.light` (built 2026-10-15, not tagged). Later, offer it on `mj:camera` for apps that don't
  use DataDungeon: a thin wrapper that requires DataDungeon's file (its only runtime dependency is
  `sqlite3`, which mj has), not a second copy that can drift. Until then `shoot` still renders
  `view`/`light` itself and appends them; whether it should stop is open (below).
- **Provider strictness by rating** (Thomas, 2026-10-16). A rating has one wording, DataDungeon's
  (`dd:g` … `dd:x`), and the DM is told the rating; nothing else enforces it. Find which cameras take
  a per-request safety or strictness setting and how it behaves, on each path: Runware's (`klein`,
  `flare`, `sunburst`, `lite`, `nano`, `hero`), OpenAI direct (`dflare`, `dsunburst`, `dhero`), Google
  direct (`dnano`, `dlite`). mj passes none today; `camera_service.cr` only recognises a refusal
  after the fact. If they exist, `shoot` could take the rating and ask for the strictest at `g`.
- **Second checks on a rating, parked** (Thomas, 2026-10-16: trust the DM's attempt, and add these
  if failures become noticeable). A text check of the description against the rating before drawing
  (the failure the cow tests point at: a description asking for the thing beats a rule against it),
  and a vision check of the picture after, mainly for G. Either could be a tool on mj's bus. Until
  then DataDungeon's `flagged` and `rating`, set by people (Curio), are the backstop.
- **Grey canvas shows through.** Runware has no text-to-image route in mj's transport, so an
  unreferenced shot edits a flat 128-grey canvas (`src/arcana/transport.cr`). In the cow tests
  (2026-10-14) it survived as a flat grey sky: `klein` seed 31337 in 3 of 4 prompts, `flare` once.
  Overlore draws a room's first picture on `klein` with its theme's seed, so this can reach the game.

## mj's own DataDungeon store
- **Decided (Thomas, 2026-10-16): each app has its own store, mj included.** mj requires DataDungeon
  as a library and stores with `DB#store`, as Overlore does. It holds what mj makes for others (the
  Bard cut-outs and their mouth frames, each linked to the picture it was edited from),
  each with its recipe. Moving an asset into another app's store is a transfer between stores, to be
  added: DataDungeon's side carries the bytes, recipe, wordings and links; Curio runs it across the
  fleet. Until then deliveries stay files plus a manifest (`outtake/bard-overlore/`).
- **0.14.0 is tagged (2026-10-17, `401dd4a`):** a recipe keeps the prompt as sent, with the named
  wordings in it and hashed versions. There are no standard styles, so mj would name, word and tag
  its own. Open: where the
  store lives (Overlore's is `~/.local/share/overlore/assets.db`), and which types to register,
  since DataDungeon's standard types are still drafts.
- **The Bard's animation graph as an asset** (Thomas, 2026-10-18: "another type of asset we should be
  able to store in DD"). `outtake/bard-graph/graph.yml`, compiled to
  `outtake/bard-overlore-graph/graph.json`, says which body frames may follow which, and is walked
  fresh on each play (`bard-walker.js`). It isn't a timeline, so none of DataDungeon's draft types
  fit: `sequence` is one fixed timeline, 3D `motion` is skeletal, and a sprite sheet's
  `ImageAnimation` is a fixed loop. Today it could only be `data`. Sketch: the graph is one asset;
  each frame is a prop, linked from it with its node and mouth shape in the link's data, so copying
  the graph copies its frames (what `bard-overlore-graph/` does by hand now); Thomas's unusable marks
  become `flagged` on the frames; the walker stays app code, named by the graph's format and version.
  Open: its own type or `data` (a name floated: `puppet`, the 2D counterpart of a rigged `figure`);
  one graph per character or per look (the cartoon and realistic Bards are two sets in one today);
  and the choreography (which pose on which line, Overlore's) is a separate, `sequence`-like thing
  that points at the graph.

## prompt parts (`shoot`), asked for by `@datadungeon`
- **Under review (Thomas, 2026-10-14):** mj sends exactly the prompt it is given, and the calling app
  (or DataDungeon's join) owns the order and the heuristics; mj measures its cameras and publishes how
  they behave. If that holds, the two items below are moot. Evidence so far: `notes/cow_order.py`
  (v1, v2) — `nano` let the later instruction win 5 of 6; `klein` and `flare` let "draw X" beat
  "don't draw X" in either order, and a "don't" alone drew nothing.
- **Return `prompt_parts`, and accept them.** Each part `{"role", "text"}` in the order sent,
  beside `prompt_sent`. The roles are DataDungeon's seven picture slots — `preamble`, `subject`,
  `description`, `theme`, `style`, `rules`, `staging` — and a role outside the list is refused on
  their side. Recipes are built (DataDungeon 0.13, `54121b7`).
- **Staging is appended after the caller's rules today, which is wrong** (`camera_service.cr:181`).
  Given one opaque prompt string there is nowhere else to put it, so my view/light words land after
  "nothing else in frame" and bury the constraints that are supposed to bind last. mj's own prompt
  craft has always ended with the rules (see `examples/prop/prop.yml`). Accepting the slots is what
  makes the fix possible: proposed joining order is **preamble · subject · description · staging ·
  theme · style · rules**, put to `@datadungeon` 2026-10-13. Their `prompt_sent` check compares
  against the fields joined, so a disagreement here means every record is stored whole — which is
  the compression story they built this for.
- **Whether these models care about slot order: measured 2026-10-14, null** (`notes/prompt-slot-order-v1.md`,
  "Result"). 36 images on `klein`, four arrangements; both rules held in all 36, by machine and by
  Thomas's eye, and the misses that did happen tracked the seed, not the order. So the order is free
  to be chosen for `prompt_sent` reconstruction. Bounds: `klein` only, text-to-image, no reference;
  Nano and editing untested. A sensitive v2 would walk instructions the model actually loses
  ("two-wheeled", "folded") through the slot positions.

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
