# `mj prop` — the prop machine

Turn a rough sketch into a **2D game prop with a clean transparent background**. Nano paints the
subject on a solid known bg; mj keys it out by distance-from-background.

```
mj prop <name|dir> [--rekey]
```

- `<name>` resolves inside the prop library (`~/.local/share/mj/props/<name>/`).
- A path containing `/` (or an existing directory) is treated as an explicit one-off dir.
- `--rekey` re-runs **only** the keying step on the existing `render.png` — no API call.

## Directory layout

```
<dir>/
  template.png   (input)  rough flat-colour massing sketch — subject silhouette + feature patches
  prop.yml       (input)  the PropSpec (below)
  render.png      (out)   raw Nano output on the solid bg
  prop.png        (out)   the keyed transparent cut-out  ← the deliverable
```

## `prop.yml` (PropSpec)

```yaml
prompt: >-                       # required. Name the bg colour here too, and "floats isolated, no ground".
  A colourful wooden circus barrel with metal hoops, painted red and gold, clean cartoon
  game-prop style, centred, on a solid pure black background, nothing else in frame.
background: [0, 0, 0]            # bg colour to render on. black=bright subjects; white/[0,255,0]/[255,0,255]=dark subjects
auto_background: true            # key the ACTUAL sampled corner colour, not the requested one (keep true)
key_low: 4                       # alpha ramp: below = transparent
key_high: 28                     # alpha ramp: above = opaque. Lower keeps thin detail; raise for cleaner cut
edge_blur: 0                     # px of box-blur on the alpha edge (0 = off)
despill: true                    # recover true F on edge pixels (strip bg tint)
defringe: true                   # subtract residual chroma halo on thin detail
defringe_band: 0                 # 0 = whole image; set 1-3 only if the SUBJECT contains the key hue
alpha_bleed: true                # flood transparent pixels w/ nearest subject colour (stops mipmap fringe)
model: "google:4@3"             # Nano Banana 2 (NOT the deprecated google:4@1)
width: 1024
height: 1024
tags: ["pirate", "metal"]        # free-form, flow into the library manifest (index.json)
```

The full keying algorithm (distance ramp, despill, defringe, alpha-bleed) is documented in
[techniques → prop keying](../techniques.md#prop-keying--how-the-transparent-cut-works). Example:
`examples/prop/`.

## The template is a reference, not a cutter

The template only guides subject + size/placement — Nano paints outside the lines and the prop is
cut from the **render**. **Bright templates → cartoon output**; **boxy templates → boxy buildings**.
Use neutral grey massing, or for ornate subjects **no template** (a blank chroma-green canvas) and
let the prompt drive. See [techniques → templates](../techniques.md#templates--a-rough-reference-not-a-cutter).

## Tuning workflow

1. First pass: `mj prop <name>` (calls the API, writes `render.png` + `prop.png`).
2. If the cut is imperfect but the render is good, edit `key_low`/`key_high`/`despill`/… in
   `prop.yml` and run `mj prop <name> --rekey` — instant, no API cost.
3. Repeat step 2 until clean. Only re-run without `--rekey` to reseed the image.

**Dark subject?** Render on white or chroma green/magenta and set `background` to match — the
distance key handles it. **Metal / reflective?** `alpha_bleed` (on by default) is what stops the key
hue reappearing as a pink/green fringe in thumbnails.

## The prop library

Props live in a relocatable tree at `Config.props_dir` (default `~/.local/share/mj/props`;
override with `$MJ_PROPS_DIR` or `props_dir:` in config). One folder per prop. Every build updates
`<root>/index.json` (`PropLibrary.record`): rows of `name`, `tags`, `model`, `width`, `height`,
`source_sha` (sha256 of `prop.yml` — changes when the recipe changes), `created`, `updated`, sorted
by name. This is the tag seam for a future asset backend. The keyed `prop.png` also feeds the
[Diorama](diorama.md) palette (as a `cut:true` entry) and gets transcoded by [`mj webp`](diorama.md#webp).

---
Related: [techniques](../techniques.md) · [Nano Banana](../nano-banana.md) · [pixelize](pixelize.md) ·
[matte](matte.md) · [diorama](diorama.md)
