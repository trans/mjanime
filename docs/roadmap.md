# Roadmap — goals, open problems & working agreements

Where the studio is headed, the hard problems still unsolved, and how to work with the user.

## ⭐ Magic Themes (the north star)

**User types ONE overall theme/style → ALL venues auto-regenerate in it, consistently.** Day + night
only (no pixel needed). This whole R&D session is the manual version of what Magic Themes would
automate.

Architecture:
- **Separate each venue's IDENTITY (fixed) from the THEME.** Identity = "Goldie the goldfish tent",
  "the arcade". Theme = a reusable **style-block** + ideally a shared **style-reference image** fed
  into *every* gen so all venues anchor to one look. This is exactly the two-reference
  (subject + style) lever [`mj decorate`](tools/base-and-decorate.md) already has.

Two hard nuts:
1. **Cross-venue style consistency.** The **shared style-reference image is the strongest lever** —
   feed one look-anchor into every venue's gen.
2. **Base-structure footprint alignment.** Lock the footprint to a guideline — a foreground prop (a
   barrel, an awning) shifts the bbox and **breaks day↔night registration**. This is the same
   unsolved "exact-footprint fit" problem the [prop machine](tools/prop.md) punts on.

## The Seamstress problem

Connecting real scenes into a seamless panorama, originals preserved. **Solved:** style + edge-lock,
and the flat-orthographic-tile framing (Nano Banana 2 — see
[stitching](techniques.md#backdrop-tiling--scene-stitching)). **Open:**
- **Structural continuity** across a seam — a railing that vanishes, a sea plane that flips to a flat
  band. A generic gap sketch doesn't encode the structures crossing the seam. The AI "declared
  success" grading only style, never tracing a structural line across — a self-judgment failure worth
  remembering: *enumerate ALL requirements (edge-lock, style, structural continuity, perspective) and
  verify each independently.*
- **Bridging two genuinely different scenes** (content + style) across one tile.
- The ideal tool is **imaginative AND masked/localized**. On Runware the two are split: imaginative
  editors (Nano/Qwen/Kontext) take no mask; mask-takers (FLUX Fill, SDXL) can't imagine. "FLUX Kontext
  Inpaint" exists in the ecosystem (fal/Replicate/ComfyUI) but is unconfirmed on Runware — **test
  empirically** (Runware docs are unreliable). Full analysis: `notes/connect-and-seamstress-v1.md`,
  `notes/inpainting-analysis-v1.md`.
- **Next fair test:** two SAME-style / SAME-perspective scenes, to isolate the stitch from the bridge.
  (The Goldie's-vs-W.C.Frank's test refs were a deliberate worst case.)

## Backdrop tiling

Kill the deck's **horizontal vanishing point** (parallel planks, or a flat tileable plank texture
projected in-engine like a Mode-7 floor) so a boardwalk backdrop tiles + scrolls + still reads deep.
Niche worst-case; most scenes (jungle/forest/sky) don't have the landmine. See
[techniques](techniques.md#backdrop-tiling--scene-stitching).

## W.C. Frank's from-scratch regen

The fancier arcade rebuild (current one is complete and working):
- Describe the interior as **what the player actually sees inside** (don't over-specify — it invents
  false signage and cramps the space).
- At **night make the tent's colored STRIPES glow like NEON tubing** — the stripes become the light
  source. Likely solves "night too dark" better than bulbs; native to a circus tent.

## Other explored-but-unwrapped threads

| Thread | State | Notes |
| --- | --- | --- |
| **`panorama`** tool | easy now | Nano Banana 2 has native ultra-wide presets (21:9 `1548×672`) — retires the old [FLUX-dims workaround](#the-flux-dims-bug). |
| **`zoom` / `enter`** (generative point-and-click) | validated technique, not wrapped | Two-ref (subject-crop + wide-scene) → a new destination scene. Aim at *under-resolved* regions for real invention; legible regions just upscale. `data/zoom/`. |
| **`mj mouth`** (AI lip-sync scorer) | designed, not built | CV landmark detectors fail on stylized faces; markers must be **AI-scored** against one human-picked max-open anchor → `openness.csv` → `tools/align.py` (Viterbi retiming, done). |
| **Character motion / "cuts"** | paused | img2img frame-chaining drifts (character melts). In-progress pose/ControlNet fix (`src/models/pose.cr`, `src/engine/pose_renderer.cr`) unfinished. |
| **sfx `layers:[…]`** | proposed | Composite sounds need stacked voices. Plus filtered-random wobble, fit peaking-Q, pitch-sweep detection. `TODO.md`. |
| **Tiled-world-evolver** | blocked on the Seamstress | Edit a snippet of a big image keeping its edges identical, so it drops back into place. Same primitive as the Seamstress. |

### The FLUX dims bug
`RunwareClient#generate` is **img2img only** (always sends a seed image — no pure text2img).
`MJ.snap_dimensions` snaps FLUX models to a stale list of /32 (not /64) widths → Runware 400s. Low
priority: Nano Banana 2's native wide aspects mean we rarely need FLUX text2img. If fixed: add a real
text2img method or make the snap list /64. Details: memory `runware-client-flux-dims-bug`.

## Working agreements (how the user wants me to work)

These are corrections the user has given — treat them as standing rules.

- **Never delete or overwrite the user's files without asking.** Generated intermediates are fair
  game; delivered art, curated cutouts, and `_*-backup` / `_*-prev` folders are not. This rule exists
  because it was violated once and it *"scares"* the user. When cleaning generated files, use a
  guarded whitelist.
- **Don't editorialize images — report, don't judge.** State the files written and the objective
  params (dims, prompt, chunk cue); let the user look and judge. Don't declare a result "great" or
  "perfect" for them.
- **Try-and-SEE before rewriting a prompt.** Show a result and hold; don't jump straight to editing
  the prompt.
- **Experiment file naming:** `ref-*` (sent to the AI), `out-*` (raw AI output), `stitch-*`
  (composited locally), plus a `prompt.txt`. Always state the prompt used. Don't pre-align images
  you're about to hand the model.
- **Ports:** assign via `~/Projects/cyclops/bin/cyclops-port <name>` (crc32-stable) — mj is **21683**,
  never a shared 4444.

---
Related: [world](world.md) · [techniques](techniques.md) · [Nano Banana](nano-banana.md)
