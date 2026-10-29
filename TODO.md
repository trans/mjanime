# mj — TODO

## Reminders for Thomas

- **Check the 3D act's rimshot, crickets and fanfare** (Thomas, 2026-10-25: remind me later; not
  essential). @overlore offered several of each; Thomas accepted the first of each for now, having
  heard them ("they are fine"). On Overlore's test landing, the stand-up act.

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
- **`mj:voice` concurrency** — **done 2026-10-21** (not yet committed): a lane per provider limit
  (ElevenLabs v3/v2 and Flash sized to the plan, songs 1, OpenAI 6), `expired` for requests
  whose caller has given up, retry on ElevenLabs' 429. See docs/tools/arcana.md "Queueing".
  **At Pro:** restart `mj-arcana.service`; it reads the plan at start (Pro: 10 and 20).
- **`wait_seconds` on `shoot`** (asked by @overlore for Thomas, 2026-10-22): a shot still queued
  when less than a few seconds of the caller's wait is left comes back `expired`, unmade and
  unbilled, as `speak` does. **Done in `1c33360`:** no attempt, nor retry, starts once
  less than the camera's typical time is left. Overlore waits 150 s and will send it once told.
- **Word times from `mj:voice`** (candidate, 2026-10-19): ElevenLabs' `with-timestamps` speech
  endpoint returns each character's start and end; untested with `eleven_v3`. Returned as cues in
  the shape of DataDungeon's `words` track (`{start_ms, end_ms, value}`, v0.15.3), an app could
  store a take's word times as they come, for choreography, instead of aligning them again.
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
- **Grey canvas shows through: fixed, 2026-10-19.** An unreferenced shot on the Runware transport
  edited a flat 128-grey canvas, and in the cow tests (2026-10-14) the grey survived as a flat sky
  (`klein` seed 31337 in 3 of 4 prompts, `flare` once). It's now text-to-image
  (`RunwareClient#text_to_image`, the same task with no references): all seven Runware cameras
  took it and drew a real sky, and the three grey `klein` cases, re-run with the same prompts and
  seed, came back with none (checked by eye: a grey sky can be warm, which a neutral-grey count
  misses; $0.32 to test).

## mj's own DataDungeon store
- **Decided (Thomas, 2026-10-16): each app has its own store, mj included.** mj requires DataDungeon
  as a library and stores with `DB#store`, as Overlore does. It holds what mj makes for others (the
  Bard cut-outs and their mouth frames, each linked to the picture it was edited from),
  each with its recipe. Moving an asset into another app's store is a transfer between stores, to be
  added: DataDungeon's side carries the bytes, recipe, wordings and links; Curio runs it across the
  fleet. Until then deliveries stay files plus a manifest (`Outtake/bard-1-2/overlore/`).
- **0.14.0 is tagged (2026-10-17, `401dd4a`):** a recipe keeps the prompt as sent, with the named
  wordings in it and hashed versions. There are no standard styles, so mj would name, word and tag
  its own. Open: where the
  store lives (Overlore's is `~/.local/share/overlore/assets.db`), and which types to register,
  since DataDungeon's standard types are still drafts.
- **The Bard's animation graph as an asset** (Thomas, 2026-10-18: "another type of asset we should be
  able to store in DD"). `Outtake/bard-1-2/graph/graph.yml`, compiled to
  `Outtake/bard-1-2/overlore-graph/graph.json`, says which body frames may follow which, and is walked
  fresh on each play (`bard-walker.js`). It isn't a timeline, so none of DataDungeon's draft types
  fit: `sequence` is one fixed timeline, 3D `motion` is skeletal, and a sprite sheet's
  `ImageAnimation` is a fixed loop. Today it could only be `data`. Sketch: the graph is one asset;
  each frame is a prop, linked from it with its node and mouth shape in the link's data, so copying
  the graph copies its frames (what `bard-1-2/overlore-graph/` does by hand now); Thomas's unusable marks
  become `flagged` on the frames; the walker stays app code, named by the graph's format and version.
  **Its own type, `automaton`** (Thomas, with DataDungeon's agreement, 2026-10-19): states and the
  moves allowed between them, walked by input (speech cues, pauses), like a clockwork figure running
  through its set positions; not only characters (a door, a torch). `puppet` is kept for a
  marionette type to come, one worked continuously by a rig. An automaton is one set of frames that
  can follow each other, so the cartoon and realistic Bards (two sets in one file today) would be two.
  **Choreography is the app's, not the script's or DataDungeon's** (Thomas, 2026-10-19, via
  `.ai/mail/received/20261019-174852Z-@overlore--re-choreography-*`): pose names in a script would
  tie it to the automata that have them, so an app's agent reads an automaton and a take's timed
  words and makes its own (as Rhubarb does mouths), maybe choosing among fitting poses each play,
  and keeps it in its own database. A script may still pin a required pose (`[pose=bow/]`).
  **Decided** (Overlore's proposal, approved by Thomas 2026-10-19): `pose` is the one body tag
  and every other tag is the voice's, translated to the engine's own (v3's `[whispers]`) when the
  take is asked for; directions come
  in three kinds, a moment (`[sighs/]`), a state until the next (a pose), a span with a close
  (`[whisper]…[/whisper]`). A take's word times and mouth cues go with the speech, not the script
  (DataDungeon's call how). For it, mj gave each pose a `means` line and rests and endings a `kind`
  (`bard-1-2/graph/graph.yml`, sent 2026-10-19). **Every link and move goes both ways** (Thomas,
  2026-10-19); a way back that breaks physics is flagged `reverse: abnormal`, taken only on purpose.
  **Under discussion (2026-10-19):**
  - *Characters:* a character as an asset holding its sheet (description, reference pictures, voice
    id), with assets linking to it (`depicts`, `voiced-by`); it would tie both Bards' automata
    together. Thomas is leaning that way; it reopens his 2026-10-13 decision not to model characters.

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
- **Security review before deployment** (Codex, 2026-10-21; `Intake/codex-review.md`, brief in
  `Outtake/review-brief.md`). **Fixed in `76e6f1e`:**
  - `reference_path` is refused;
  - `reference_url` only fetches public addresses, or loopback under `/media/`, pinned, with
    each redirect checked and the cap applied while reading;
  - `output_path` is confined to `~/.local/share/mj/out` and never overwrites;
  - every paid call is in `spend.jsonl`;
  - the unit is sandboxed (home a tmpfs, runtime dir hidden, syscall filter, memory cap;
    exposure 8.0 → 3.7);
  - `mj serve` listens on loopback, checks Host and cross-site requests, escapes what it
    prints, and checks slugs; it joins the bus only with `MJ_BUS=1`;
  - `just env-pull` writes the key file privately;
  - the ONNX shim checks the model's output.

  **Open:**
  - **Senders aren't authenticated on the bus** (Arcana's server; mail sent to `@arcana`
    2026-10-22). **arcana 0.37 stamps `verified`** (installed 2026-10-24), and mj-arcana
    serves only `MJ_ARCANA_CALLERS`, verified, when it's set: unset on the workstation,
    set on a deployment (Thomas, 2026-10-24). mj-arcana joins with **a key of its own**
    (Thomas, 2026-10-24), from `ARCANA_KEY_FILE`, which both units set.
    Waits on Overlore's calls signing before its box sets the list. A lost `/var/lib/mj`
    leaves the addresses held on that bus until arcana has a way to free them.
  - **Paid only: settled, nothing to change** (@overlore, 2026-10-22). Overlore checks a
    player's balance before every paid request and charges twice mj's `usd`; no price limit
    in mj, since one set too low would stop the game (Thomas, 2026-10-22). Lost replies
    aren't worth handling yet (Thomas), so request ids in the ledger aren't needed.
  - **A bound on queued requests** in arcana-core's dispatcher (not yet asked).
  - **Outrageous-only limits** (Thomas, 2026-10-22: Overlore caps request sizes, so mj
    refuses only the obviously outrageous; a tight limit would stop the game). Proposed:
    10,000 characters of text, instructions or context; songs up to 10 minutes; 16
    references; `wait_seconds` up to an hour. **Done in `230c1d8`**. Overlore's largest
    are far under (a 441-character line). The queue's expiry also trusts the sender's clock.
  - **The `mj` bus service** (`src/bus_service.cr`) still trusts every path it's given,
    when it runs.
  - **A dedicated service user:** the server now gets a system unit with a dynamic user
    (`deploy/server/mj-arcana.service`), as @cyclops asked (2026-10-22). Not yet run as a
    system unit: that needs root, which this workstation's session hasn't.
- **Deploying mj-arcana to a server:** `just install-server`, as root, builds only mj-arcana
  and installs the system unit (deploy/README.md, "On a server"). Handed to @cyclops, who
  deploys, 2026-10-22; it signed the unit off the same day, and `mj/production`'s keys are
  all set (prod reuses local's values).
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

## hearing, recording, music cost (mj's suggestions, 2026-10-27; Thomas: add them, 2026-10-28)
- **A `listen` tool (the one that would help most).** mj can't hear: every report on a take is
  indirect (Whisper for the words, spectrograms for the cuts, loudness meters, a beat tracker), so
  every take waits on Thomas's ears, even the plainly broken ones. The audio counterpart of Nano
  Banana for pictures: send a take, and a reference when it helps, to a model that can hear (Gemini)
  with narrow questions: the same voice as this one? the same tempo? a click, or a cut mid-word? still
  a Scottish accent? It reports; Thomas still judges. **Test it first on cases with known answers:**
  the "elf" pitch-shift Thomas rejected, and the three Scottish takes Whisper misheard. If it can't
  hear those, it isn't worth having.
  **Tested 2026-10-29** (outtake `listen-test/README.md`, $0.28): Gemini 3.1 Pro and 3.8 Flash, 28
  clips with planted faults and Thomas's past calls.
  - **Glitches: no.** Planted clicks, cuts, dropouts and distortion were found 2 of 8 at best,
    different ones at different thinking levels. No model reported a glitch in a clean take.
  - **Speakers: no.** Both models called the Announcer and Gerald the same speaker.
  - **Pitch shift heard alone: no.** Neither model heard any pitch-shifted take as processed.
  - **Pitch shift against a reference: yes, with 3.1 Pro.** Given the original, it called all five
    shifted Henrys, "elf" included, higher and processed (11 of 12). It mixes up pitch and pace.
  - **Words in an accent: yes.** Both models heard the Scottish u-2 and u-9 as written, where Whisper
    failed. On u-4, Flash and Whisper both heard "what's a hotel" for "like a hotel".
  - **Accent:** 3.8 Flash was right 10 of 11.
  So no general `listen`. **Built instead (Thomas: "get what you can that is useful out of it",
  2026-10-29): `mj listen`** (`docs/tools/listen.md`, `src/engine/listen.cr`). It has:
  - measured glitch checks: 7 of 8 planted faults found, nothing in mj's 339 real takes;
  - Whisper and Gemini 3.8 Flash on the words, marking where both differ from the script;
  - Gemini's guess at the accent;
  - Gemini 3.1 Pro's "processed" answer against a reference.
  **Still to do:** a `listen` tool on the bus, if another agent wants one.
- **The recording pipeline as an `mj` command.** The recording runner, the Whisper word check,
  Rhubarb-to-cues, the cutters and the choreography script live in a session's scratchpad and are
  rebuilt every session. As tested code in the repo, with a page in `docs/tools/`, anyone can run
  them; a skill for it would then be a few lines (where the voice key comes from, the command, the
  page).
- **Price Eleven Music.** `music` is logged with `cost: null`, since Eleven Music returns no price
  (`docs/tools/spend.md`). Read the plan's character counter before and after a song and price the
  difference.

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
- **Port the Bard's Python scripts to Crystal** (Thomas, 2026-10-19). They're Python only for
  speed while experimenting (numpy and scipy do whole-image maths in a line), and live in
  `Outtake/`, not mj. Two parts:
  - *The graph and its package* first, as an mj command: `bard-1-2/graph/graph.py` (compile `graph.yml`:
    neighbour lists, moves, unusable marks) and `bard-1-2/overlore-graph/build.py` (cut each frame to
    webp at its stage offset, write `graph.json`). YAML in, JSON out, crops by `magick`: a direct
    port, and the way in for the `automaton` type in mj's DataDungeon store (above). The preview
    page's builder (`bard-1-2/preview/build.py`) can follow. `bard-walker.js` stays JavaScript.
  - *The compositing:* `bard-1/pitch/compose.py` (heads onto pose bodies; `EYES`, `HAND`),
    `bard-1-2/poses/mend_neck.py` and `mend_write.py`, `bard-1-2/gesture/composite*.py`,
    `bard-1-2/mouths/composite.py`, `align.py`, `measure.py`. Bind ImageMagick's C API (MagickWand) from
    Crystal, as `just build` already does for the ONNX shim: it has the differences, thresholds,
    morphology (dilate, open), Gaussian blur, connected components (dropping specks) and masked
    blends these use. Filling holes in a mask isn't one call there; a flood from the border, as
    `mj matte`'s Tier 1 does (`src/engine/matte.cr`), would do it.
- **UV region editor** — port the in-canvas region tool into mj's web UI. Define a box/ellipse/(polygon)
  on an image by hand and read back normalized `{u,v,w/rx,h/ry}` numbers to paste into code — same UV
  works at any canvas size, in editor and renderer alike. Design doc copied to `notes/uv-region-editor.md`
  (from siliconcircus funhouse). Two immediate mj fits: (a) mark a **prop cutout box** / relight-mask
  region, and (b) the **per-frame `(dx,dy)` alignment offset** that kills the frame-drift shimmer when we
  swap whole AI-rendered frames — the same drift problem behind the mouth/lip-sync + connect-seamstress
  work. Self-contained component: `<canvas>` + cover-fit transform + region list + pointer/wheel handlers
  + live readout + JSON in/out. Endgame it points at: transparent cutout of just the moving part over a
  static base (no mask, no offsets) — the editor is the good-enough-now way to find where the cutout sits.
