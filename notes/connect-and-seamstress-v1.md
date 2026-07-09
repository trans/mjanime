# Connecting Scenes & the Seamstress Problem — Analysis (v1)

_Investigation 2026-07-05 → 2026-07-07. Companion to [`inpainting-analysis-v1.md`](inpainting-analysis-v1.md). All experiment artifacts live in `data/strips/mine/experiment/` (folders 10–20, gitignored). Each folder follows the convention `ref-*` (sent to the AI), `out-*` (raw AI output), `stitch-*` (composited locally), plus a `prompt.txt`._

## Goal

Connect real, pre-made scenery images into one long **seamless** panorama for a 2D platformer, with the
**originals left exactly as they are** (they are the real assets and must glue back / read as authored).
Sub-case of the [tiled-world-evolver](inpainting-analysis-v1.md#addendum-2--two-machines-different-degrees-of-freedom-the-key-synthesis).

## The mechanism that works (overlay-and-align)

1. **Nano invents the in-between.** Feed the two shops as references with the *pixel-match* recipe — Nano
   draws the connecting image whose **far-left edge = shop-1's right edge** and **far-right edge = shop-2's
   left edge**, with an invented midway between. (This is the easy part.)
2. **Overlay it ON TOP of the untouched originals**, sliding **horizontally only** to best-align its
   edge-copies onto the real shop edges (SSD template match). out-nano wins on top; the originals show past
   its two ends. No cropping, no scaling, no vertical shift.
3. Result: `real shop | out-nano (edge-copy + midway + edge-copy) | real shop`, with two seams at
   out-nano's outer edges. See `19-overlay-v2/` (`stitch-overlaid.png`).

**Hard constraint discovered: in and out must be the SAME HEIGHT (width is flexible).** Generating the
connector at a different height than the shops (e.g. 672 vs the shops' 768) breaks alignment and leaves
black edges — the root of several failed attempts. Nano's **only 768-tall supported size is `1344×768`**.

**Nano's composition is aspect-driven (same prompt, different dims):**
- Wide/flat `1536×672` → thin shop-edge fragments + a big invented middle (the *in-between* we want).
- Squarer `1344×768` → two nearly-full **compressed** shops + a tiny middle (edges are the shops' outer
  sides — useless for the overlay).
- The bind: the composition we want prefers a wide/flat aspect, but that aspect is 672 tall; the correct
  768 height only comes at the squarer 1344 width. Fix: **push the prompt** ("show only a thin sliver of
  each shop; the middle two-thirds is open pier") to force the in-between at 1344×768. This worked
  (`19-overlay-v2`, alignment: N-left→Goldie col 744, N-right→Frank's col 176).

## Other approaches tried (and why they're limited)

- **Single-compose** (all shops as refs in one Nano call): seamless *by construction* (one generation),
  but **size-capped** (~1536 wide → shops shrink past ~3 shops). Temperature ~1.2–1.8 makes a single
  compose richer; but temperature **hurts stitching** (independent windows diverge → e.g. a doubled shop,
  `08-stitch-temperature`). Good default for ≤~3-4 shops; doesn't scale to a long world.
- **Windowed stitch + exposure-match + minimum-error seam** (`06-windowed-stitch`): classic panorama
  assembly across two Nano windows. Colour-match kills the tone band, min-error seam kills the crossfade
  ghost — but the join between two *independent generations* still shows.
- **Edge-locked SDXL inpaint of the gap** (`11`,`13`,`15`,`16`,`18`,`19`,`20`): preserves the shops exactly
  and generates only the middle. Works mechanically but see the seamstress problem below.

## The Seamstress Problem (the real blocker)

Two real scenes — even similar ones — **never** meet at a tidy pattern discontinuity you can "smooth over."
Where they meet there is a **real gap**: misaligned deck lines, a railing at a different height, missing
details that must be *invented* to reconcile the two sides. **Each seam is a small scene in its own right,**
and mending it needs genuine **redrawing with understanding**, not smoothing.

Consequences, confirmed empirically:
- **SDXL inpaint is a pattern-filler, not an imaginative one.** High strength (~0.85) → it reinvents the
  band into surreal, wavy, Dali-esque distortion (`20-heal-compare/stitch-sdxl-s030` and earlier). Low
  strength → it barely touches the mismatch. There is no strength that *heals*, because healing needs
  judgment it doesn't have.
- **Classic blending** (alpha feather; and by extension multi-band/Poisson) fixes *tone* but **ghosts
  structure** — it can't invent the missing detail to fix a misalignment.
- So the seamstress must be **both**: **imaginative** (redraws the seam-scene) **and localized/masked**
  (only touches the seam, leaves the rest exact). Nano/Qwen/Kontext imagine but can't stay in their lane;
  FLUX Fill / SDXL stay in their lane but can't imagine. Neither is a seamstress.

## Model research — is there an imaginative + masked editor? (2026-07-07)

On Runware's `imageInference`, the two capabilities are split and **not combined**:

| Model | AIR | Imaginative | Accepts maskImage |
|---|---|---|---|
| FLUX.1 Kontext [dev] | `bfl-flux-1-kontext-dev` | ✅ instruction edit, "preserves unedited regions" | ❌ (refs + instruction, no mask per docs) |
| Qwen-Image-Edit | `runware:108@20` | ✅ 20B semantic edit | ❌ (referenceImages only) |
| Nano Banana (Gemini) | `google:4@1` | ✅ | ❌ (confirmed rejects seedImage/maskImage) |
| FLUX Fill | `runware:102@1` | ❌ pattern-filler | ✅ (no strength, no maskMargin) |
| SDXL "XI Inpainting" | `civitai:862813@965389` | ❌ pattern-filler | ✅ (maskMargin ok) |

- The seamstress we want — **"FLUX Kontext Inpaint"** (image + instruction + **binary mask**, edits
  constrained to the region, imaginatively) — **exists in the ecosystem** (BFL / ComfyUI / fal.ai /
  Replicate) but was **not confirmed exposed on Runware**.
- Two caveats worth remembering: (1) **Kontext already "preserves unedited regions" by instruction**, so on
  Runware you could feed it a *cropped seam window* and say "redraw only this seam," approximating a masked
  seamstress. (2) **Runware docs are unreliable** — they omitted Nano's real params — so "Kontext has no
  maskImage" should be **tested empirically**, not trusted.

## Status & next steps

- **Overlay-and-align mechanism:** works (same-height, horizontal, on top). `19-overlay-v2`.
- **Seamstress:** OPEN. Candidate order to try next time:
  1. Empirically test whether Runware's FLUX Kontext accepts `maskImage`.
  2. If not, use **Kontext via instruction on a cropped seam-window** ("redraw only this seam to reconcile
     the two sides, keep the edges") and paste the seam back.
  3. Else go **off-Runware** (fal.ai / Replicate) for confirmed **FLUX-Kontext-Inpaint** (mask + instruction).
- Reminder: the seamstress is also the general primitive for the **tiled-world-evolver** — imaginative,
  edge-locked, region-constrained editing.

## Key experiment folders

`10-connect-two-refs` (registration idea), `13-connect-hardmask` (hard-mask SDXL, gap widths),
`14/15/16` (Nano-fill + SDXL-seal hybrids), `17-connect-samescale` (the 768-height fix),
`19-overlay-v2` (**the working overlay-and-align**), `20-heal-compare` (SDXL vs feather heal — both fail).
