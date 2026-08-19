# `mj pixelize` — AI pixel-art restyle

Redraw an image as **hand-drawn pixel art** (8-bit / 16-bit) via Nano Banana 2, with optional
transparency and an optional deterministic snap pass.

```
mj pixelize <dir> [--rekey]
```

- `<dir>` is a **literal path** — unlike `mj prop`, pixelize does **not** resolve inside the prop
  library. Pass the full path.
- `--rekey` re-runs **only** the finish/keying step on the existing `redraw.png` — no API call.

## Directory layout

```
<dir>/
  image.png    (input)  the source to restyle (e.g. a venue's day master render)
  pixel.yml    (input)  the PixelSpec (below)
  redraw.png    (out)   raw AI redraw (Stage 1)
  pixel.png     (out)   final (Stage 2: optional snap + optional keying)  ← the deliverable
```

> With `background: keep` and `snap: false`, `redraw.png` and `pixel.png` are identical — the
> finish pass is a no-op. `redraw.png` is always the raw model output; `pixel.png` is after the
> post-passes.

## `pixel.yml` (PixelSpec)

```yaml
style: 16bit             # 8bit | 16bit — selects the base prompt template / era
prompt: ""               # optional EXTRA instruction, appended (this is where the resolution cue goes)
model: "google:4@3"      # Nano Banana 2; google:4@2 (Pro) also works
width: 1024
height: 1024
snap: false              # deterministic pixel-perfect pass (needs ImageMagick). Usually OFF.
grid: 128                # snap only: true pixel resolution (8bit~64, 16bit~128)
colors: 32               # snap only: palette size (8bit~16, 16bit~32, up to ~256)
background: transparent  # transparent | keep | "#RRGGBB"
# transparent-keying knobs (only when background: transparent) — routed through the PROP keyer:
key_low: 40
key_high: 110
despill: true
defringe: true
defringe_band: 2         # edge shell only, so pink/magenta pop-art colours in the subject survive
alpha_bleed: true
auto_background: false   # keep FALSE: the redraw is prompted for flat #FF00FF; corner-sampling can grab a subject colour
```

Example: `examples/pixel/`.

## How the prompt is built (verified against source)

`Pixelize.build_prompt` assembles, in order:

1. **The style base** (verbatim):
   - `8bit` → *"Redraw in an 8-bit pixel art style, NES era, with chunky blocky pixels and a small
     limited color palette (NOT just a pixelation)."*
   - `16bit` → *"Redraw in a 16-bit pixel art style, SNES era, with clean pixels, pixel shading and
     a limited palette (NOT just a pixelation)."*
2. **The text-exception** (always appended, verbatim): *"…for any regions containing text, letters,
   words, numbers or signage, do NOT redraw the lettering as shapes — instead keep it as a straight,
   crisp pixelated (downscaled) version of the original text…"* — this is why signage stays legible;
   **you don't add it yourself.**
3. **The background clause**: `transparent` → *"…solid flat magenta (#FF00FF) background, nothing
   else."*; `keep` → nothing; `#RRGGBB` → *"…solid flat #RRGGBB background, nothing else."*
4. **Your `prompt`**, appended last.

> The style base alone under-stylizes. **Put the resolution cue and "artist draws it" framing in
> `prompt`** — see [the pixel recipe](../techniques.md#the-pixel-recipe). This is the single most
> important thing to get right, and the [pixel-chunk lever](../techniques.md#the-pixel-chunk-lever)
> is how you dial coarseness per tier.

## The finish pass (Stage 2)

`Pixelize.finish`: (1) `snap` first if enabled, then (2) key if `background: transparent`.

- **snap** (`magick`): downscale to `grid`×`grid`, quantize to `colors` (no dither), nearest-neighbour
  (`-filter point`) upscale back to `width`×`height`. **Off by default** — the raw AI redraw already
  reads as pixel art, and snap is *not* how you get "the pixel look" (that's the prompt's job).
- **transparent keying** routes through **`Prop.key_out`** with `background=[255,0,255]` (magenta),
  so pixel sprites get the same despill / defringe / alpha-bleed fringe defence as props. Without it
  a magenta fringe outlines the sprite and resurrects on downscale.

## Gotchas

- **Under-stylized (looks like the photo)?** The prompt is too weak — strengthen the resolution cue;
  don't reach for `snap`. Check you're not on `google:4@1`.
- **A "preserve the detail" clause fights the redraw** → near-photoreal output. Keep the prompt
  pushing the style.
- **`auto_background: true` on a transparent pixel job can leave an opaque magenta field** if a
  subject/floor colour reaches a corner. Keep it `false` (the default here); the redraw is prompted
  for a known flat magenta.

---
Related: [techniques → pixel recipe](../techniques.md#the-pixel-recipe) · [Nano Banana](../nano-banana.md) ·
[prop](prop.md) · [world](../world.md)
