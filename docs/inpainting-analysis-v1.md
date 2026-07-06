# Region Inpainting — Problem & Solution Analysis (v1)

_Investigation date: 2026-07-05. Companion visual exhibit: [`inpainting-analysis-v1.html`](inpainting-analysis-v1.html) (self-contained, open in a browser). Live artifact: https://claude.ai/code/artifact/b66375f0-24a6-4ddf-a714-0b4c375b408c_

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

## Evidence & artifacts

- Visual exhibit: [`inpainting-analysis-v1.html`](inpainting-analysis-v1.html)
- Raw outputs from this investigation: `data/strips/mine/experiment/` — notably `rich_sketch_seed.png` → `rich_sketch072.png` / `rich_sketch085.png` (the successes), `out_fluxfill.png` and `sdxl_empty.png` (the instructive failures).
