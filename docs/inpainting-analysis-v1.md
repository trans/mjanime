# Region Inpainting — Problem & Solution Analysis (v1)

_Investigation date: 2026-07-05. Companion visual exhibit: [`inpainting-analysis-v1.html`](inpainting-analysis-v1.html) (self-contained, open in a browser). Live artifact: https://claude.ai/code/artifact/b66375f0-24a6-4ddf-a714-0b4c375b408c_

> **⚠ Correction — read this first. The "solution" below is NOT solved.** The recipe
> matches *style* and preserves *edges*, but it does **not** produce a structurally
> seamless transition. In the "success" images the pier railing simply disappears across
> the gap, the sea changes from a receding plane to a flat vertical band, and the deck
> depth doesn't connect. **Structure was completely unaccounted for, and — more
> importantly — the AI (me) declared success anyway, having graded itself only on style.**
> See the [Addendum](#addendum--correction-the-mis-judgment) for the full record. This
> document is preserved partly _because_ of that mis-judgment.

## The goal (two layers)

1. **Near-term — scenery strips.** Take a line of simple scenery images, stylize them, and fill the gaps between them so the result is one long seamless horizontal background for a 2D platformer. (`minanime strip`)
2. **Ultimate — a tiled world evolver.** Take a *snippet* of a large image, enhance/edit it per instructions such that the snippet's **edges stay byte-identical**, so it drops back into the exact same spot in the large image. Enhance and fill a world one region at a time.

Both layers are the **same primitive**: edit a masked region so it (a) matches the surrounding art style and (b) preserves its boundary exactly.

## The core problem

Generate/enhance a region of an illustration that is simultaneously:

- **Edge-locked** — the pixels outside the region are untouched, so it tiles back seamlessly.
- **Style-matched** — the fill looks like the surrounding art, not a different renderer.
- **Content-controlled** — it contains what we want, not what the model hallucinates to fill space.

These three pull against each other, and the tooling landscape hides a trap (below).

## What we tried, and what each attempt taught

1. **Splice pipeline, FLUX Fill (`runware:102@1`).** Composite `[edgeA | gap | edgeB]`, mask the gap, inpaint, splice the middle back.
   - Edge-locked ✓ (mask preserves context). But the style was soft/painterly — "oil painting" — against crisp storybook source art. Also: FLUX Fill *refines the seed under the mask* rather than generating from noise, so a **black gap returns black** — the gap must be pre-filled with real pixels.
2. **Nano Banana (`google:4@1`) reference editing.** Feed the composite as a reference image, instruct it to fill the gap.
   - Style matched beautifully (it's the same engine the source art was made with). **But Nano recomposes the whole frame — it has no mask and cannot preserve edges.** Splicing its output back reintroduced seams (a doubled crate at the boundary). Confirmed empirically: Runware returns `400 unsupportedParameter` for `seedImage`/`maskImage` on `google:4@1`.
3. **Full Nano panorama.** Let Nano compose both tiles into one image.
   - Gorgeous and coherent, but it *redraws* the art and is capped at ~1344 px — doesn't scale to long strips and doesn't preserve originals. Not a tiler.
4. **Alignment discovery.** The gaps "faltered" because the two source images had their **waterline 49 px apart and dock edge ~88 px apart** — different vanishing points. A sloping horizon can't be reconciled by any gap. The fix is **horizon-registration**: shift (or vertically scale) tiles so their waterlines are level *before* building the gap. The naive edge-extend pre-fill also *encoded* the misalignment as visibly stepped streaks.
5. **Edge-locked inpaint on the aligned seed — the decisive test.** FLUX Fill vs SDXL illustration inpaint (**XI Inpainting, `civitai:862813@965389`**), both mask-locked, plus sketch guidance.
   - FLUX Fill: still soft, hallucinated buildings.
   - SDXL at strength 1.0: crisp and in-style, but with no sketch it **forces structures** (gazebos, beach huts) into the empty region.
   - SDXL + **crude sketch** at strength ~0.72–0.85: renders the sketch into finished in-style art, empty of junk, lights exactly where drawn, edges preserved. **This is the answer.**

## The trap (why "AI can't do this" felt true)

**The best _style_ model (Nano) has no mask support; the models _with_ mask support were a notch behind on style.** So every time a style miss pushed us toward Nano, we abandoned the one property (edge-locking) the real goal depends on. Edge-preserving local editing is a *solved* capability — it lives in the **masked-inpaint** family (FLUX Fill, SDXL inpaint checkpoints), never in the instruction-editors (Nano, Kontext). The gap was a tooling seam, not a capability ceiling.

## The solution (recipe)

> **SDXL illustration inpaint + mask (edge-lock) + crude sketch + strength ~0.72–0.85 + cleaned negatives.**

- **Model:** XI Inpainting (SDXL) — `civitai:862813@965389`. Crisp storybook style; add `watermark, signature, text, gazebo, pavilion, poles, structure, building` to negatives (it bakes a watermark otherwise).
- **Mask:** black = keep, white = regenerate, feather the boundary. `maskMargin` (~96) crops to the region + margin and composites back — supported on SDXL, **not** on FLUX Fill (`unsupportedArchitectureMaskMargin`).
- **Sketch:** pre-fill the region with a crude guide — color bands for major zones, plus drawn hints for specific elements (a wire + dots renders string lights across a gap). A *flat* sketch yields a flat fill; a *richer* sketch (gradient sky, cloud blobs, wave dashes, perspective plank lines) renders into finished art. The sketch is what controls content and prevents hallucinated structures.
- **Strength:** ~0.72–0.85. Lower = more faithful to the sketch (flatter); higher = more rendered detail but risks ignoring the sketch and hallucinating.
- **Dims:** width/height must be multiples of 64 (pad the canvas, e.g. 1520 → 1536).
- **Prereq:** horizon-register tiles (shift or vertical-scale to a common waterline) before building the region.

## Why it works (mental model)

Masked inpainting preserves everything outside the mask by construction (composite-back), so edges are free. The *sketch* supplies the low-frequency structure the model would otherwise invent, converting "fill this empty space with something" (hallucination) into "render this specific rough thing in your style" (control). Strength is the dial between "obey the sketch" and "add detail."

## Not yet built

- **Horizon-registration** as an automatic pre-step (detect each tile's waterline; shift/scale to a shared height). Done by hand so far.
- **Auto-sketch generation** for the strip case (aligned bands from detected horizon/deck + a carried light-wire), vs. accepting a hand-drawn sketch per region (the world-evolver case).
- **Pipeline wiring**: replace the current Nano/FLUX bridge in `src/engine/strip_builder.cr` with the SDXL sketch-inpaint engine, exposed as a reusable "mask a region + sketch + edge-locked inpaint + composite back" primitive.

## Addendum — Correction: the mis-judgment

Added after the user pointed out what the original write-up (and the AI that wrote it) missed.

**The technical fact.** The recipe achieves *style match* and *edge-lock*, but not *structural
continuity* — which is the actual definition of "seamless." Concretely, in `rich_sketch072.png`
(labelled a "success"):

- **The pier railing is not continued.** Both shops carry a rope-and-post railing along the
  water's edge; the generated gap has none. A fence with a missing middle.
- **The sea is not one surface.** Mirror-calm reflection (left) → a flat band of cartoon
  wavelets (middle) → sparkle (right). The middle reads as a vertical wall of water, not a
  receding plane; the ocean's perspective does not continue.
- **The deck plane / front edge doesn't connect in depth**, and a gray corner remains.
- Elsewhere in the session, structures cut at a boundary (e.g. a tent) were left uncompleted.

The root cause is that the controlling sketch was **generic** — flat sky/sea/deck bands + a
light wire. It never encoded the *specific* structures that cross each seam (extend this
railing, complete this tent, continue this water plane at this depth). So the model rendered a
plausible generic stretch, not a continuation. A real solution must continue the crossing
structures — which is much harder than filling empty space, and remains **unsolved**.

**The meta fact (why this is preserved).** The AI evaluated the result on the single dimension
it had spent the most effort on — style — and let "renders as pretty, in-style scenery" stand in
for "seamless." It did not trace one structural line across the boundary, though the broken
railing was in plain view. Its stated confidence ("this is the recipe", "seamless") was
inherited from what it was optimizing, not measured against the actual requirement. This is a
repeatable LLM failure mode worth naming: **fixate on the salient/effortful axis, then grade
yourself on that axis** — a self-assessment that is narrow and self-confirming. The correct check
would have been to enumerate the requirements (edge-lock, style, *structural continuity*,
perspective) and verify each independently, rather than judge from overall visual plausibility.

**Status:** style + edge-lock — demonstrated. Structural/perspective continuity across the seam —
**open, and the harder half of the problem.**

## Addendum 2 — Two machines, different degrees of freedom (the key synthesis)

The whole investigation kept conflating two problems. They are not the same problem and must not
share a tool:

| | **Generate from scratch** (the strip) | **Patch / evolve existing** (world tile) |
|---|---|---|
| Surrounding pixels | free to redraw | **fixed** — must return byte-identical |
| Position of the pieces | free to move / scale / align | **fixed** — must slot back in place |
| Aligning mismatched neighbours | just move them | can't — the interior must absorb it |
| Right tool | full-control compose (Nano panorama) | edge-locked inpaint (mask) |
| Sides | faithfully redrawn (accepted) | pixel-exact (required) |

Consequences:

- **Moving/scaling to align is legal ONLY in generate-from-scratch.** In patch/evolve the neighbours
  are nailed in place, so alignment-by-repositioning is off the table.
- **The horizon-mismatch pain was a strip-only artifact.** It came from stitching two *independently
  generated* images with different horizons. A real evolver works *inside one already-coherent
  image*, so the region's edges are already mutually consistent — there is nothing to align. The
  evolver never has that problem.
- Therefore the two goals stop competing:
  - **Strip (from scratch):** feed the original tiles as references; the model self-aligns (it may
    shift a side up/down) and composes one coherent panorama — continuous railing, deck, and water.
    Validated: `data/strips/mine/experiment/interior_nb1.png`. Sides come back faithfully redrawn,
    not pixel-exact — accepted for this mode.
  - **Evolver (patch existing):** edge-locked inpaint, no alignment needed. Open problem: continue
    the *specific* structures crossing the fixed seam (railing, a cut object) — needs a
    **structure-aware** sketch, not a generic one.

Emerging open sub-problem for **multi-tile** strips (>2 shops): pairwise panoramas each redraw the
shared middle shop *independently*, so adjacent panoramas won't match on the shared shop for
stitching. Unsolved; do not hard-code a stitching strategy until it's cracked.

## Evidence & artifacts

- Visual exhibit: [`inpainting-analysis-v1.html`](inpainting-analysis-v1.html)
- Raw outputs from this investigation: `data/strips/mine/experiment/` — notably `rich_sketch_seed.png` → `rich_sketch072.png` / `rich_sketch085.png` (the successes), `out_fluxfill.png` and `sdxl_empty.png` (the instructive failures).
