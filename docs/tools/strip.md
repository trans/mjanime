# `mj strip` — scenery strips (seamless panoramas)

Take a row of ordered source images, optionally restyle each, invent transition terrain between
neighbours, and concatenate into **one long seamless horizontal PNG** for a 2D platformer.

```
mj strip <dir> [out.png]        # default out = <dir>/strip.png
```

`<dir>` holds ordered source PNGs (`01.png`, `02.png`, …) + a `strip.yml`. Needs at least 2 sources.
Needs `RUNWARE_API_KEY`. Example config: `examples/strip.yml`.

## Pipeline

1. **Resolve & normalise** — sources from `strip.yml`'s `sources:` (explicit order) or sorted
   `*.png` (excluding `strip.png`). Tiles normalised to a common height (from `height:` or the median
   source height), snapped to /64.
2. **Prepare each tile** — `passthrough: true` uses the source **untouched** (only gaps get
   generated — use this when the art is already styled). Otherwise `stylize` runs an **img2img
   restyle** (SD checkpoint, `tile_strength`).
3. **Bridge each neighbour pair** — invent transition terrain from tile-A's right edge to tile-B's
   left edge (see below).
4. **Stitch** — `hconcat(tile | bridge | tile | bridge | …)`, write the strip (pure Crystal
   compositing via stumpy_png — no ImageMagick).

## `strip.yml` (StripScript)

```yaml
title: "Fantasy hills panorama"
passthrough: false               # true = don't restyle tiles, only generate the gaps

# Stylization (per source tile, img2img):
style_prompt: "lush fantasy landscape, painterly, storybook game background, side-scrolling scenery"
negative_prompt: "characters, people, text, watermark, ui"
tile_model: "civitai:4384@128713"   # any SD1.5/SDXL checkpoint on Runware
tile_strength: 0.55              # lower = keep source composition; higher = more restyle
tile_steps: 30
tile_cfg_scale: 3.5
height:                          # normalized tile height (omit = infer from sources)
tile_width:                      # fixed width per tile (omit = per-source aspect)

# Gap bridging (invented terrain between two tiles):
bridge_prompt:                   # nil → falls back to style_prompt
bridge_model: "runware:102@1"    # FLUX Fill (mask inpaint). Prefix google: → Nano reference path
gap_width: 512                   # width of invented terrain
context_width: 192               # px of each neighbour's edge fed in as context
feather: 48                      # seam softening
bridge_steps: 30
bridge_strength: 1.0

sources:                         # optional explicit order; nil → sorted *.png
```

## Two bridge engines (chosen by `bridge_model`)

The build crops `context_width` px of each neighbour onto a seed canvas around a `gap_width` gap,
then:

- **`runware:102@` (FLUX Fill, default)** → `bridge_inpaint`: pre-fill the gap with a horizontal
  blend, build a feathered white mask over the gap, and inpaint. FLUX Fill preserves the edges and
  ignores strength. Output is soft/painterly — mismatches crisp illustration art.
- **`google:…` (Nano Banana)** → `bridge_nano`: pre-fill the gap by **edge-extension** (repeat edge
  columns — a horizontal blend renders as streaks under Nano), then `edit_references` with a
  camera-locked "repaint ONLY the middle strip, keep left/right unchanged, no text" instruction, at
  the nearest supported Nano size, resized back. **Style-matches Nano-authored source art far
  better.** See [scene stitching](../techniques.md#backdrop-tiling--scene-stitching).

Only the middle `gap_width` strip is kept from each bridge render.

## What works, what's still open

- **`passthrough` + Nano bridge** is the mode for already-styled Nano art (matches style; only the
  gaps are invented).
- **Solved:** style + edge-lock. **Open — the Seamstress:** *structural continuity* across a seam
  (a railing that vanishes, a sea that flips from receding plane to flat band) and *bridging two
  genuinely different scenes*. A generic gap sketch doesn't encode the structures crossing the seam.
  Full analysis: `notes/connect-and-seamstress-v1.md`, `notes/inpainting-analysis-v1.md`, and
  [roadmap → Seamstress](../roadmap.md#the-seamstress-problem).

---
Related: [techniques → stitching](../techniques.md#backdrop-tiling--scene-stitching) ·
[Nano Banana](../nano-banana.md) · [diorama](diorama.md) · [roadmap](../roadmap.md)
