# `mj base` & `mj decorate` — two-stage template generation

A two-stage path for template-guided building generation: **Stage 1** turns a flat-colour sketch
into a plain structural master; **Stage 2** redraws that master decorated in a style/theme.

> In practice most venue work now goes through [`mj prop`](prop.md) (prop-on-solid-bg) rather than
> base→decorate. These two remain the structural-master path and the model for **Magic Themes**
> (identity master + reusable theme block) — see [roadmap](../roadmap.md#magic-themes).

## `mj base` — Stage 1 (structural master)

```
mj base <dir> [strength]      # writes <dir>/base.png
```

`<dir>` holds `template.png` (rudimentary flat-colour sketch: silhouette + door/window colour
patches) + `base.yml`. Optional `strength` arg overrides the spec for quick sweeps. Img2img (the
template is the seed image; output inherits the template's dimensions). Example: `examples/base/`.

```yaml
# base.yml (BaseSpec)
prompt: "..."                 # legend text is just part of the prompt ("the dark-red patch is the doorway")
negative_prompt: "decoration, trim, stripes, bunting, lights, ornament, clutter, scenery, ground, people, text..."
model: "civitai:4384@128713"  # SD1.5 — FLUX img2img underperforms on flat masks
strength: 0.7                 # plain↔rich structure knob (~0.7 = rich but undecorated)
steps: 30
cfg_scale: 4.5
```

The point of the base is a **plain, undecorated, structurally-faithful** render — the reusable
master reference. The default negative prompt actively strips decoration so decoration is added
later, deliberately, in Stage 2.

## `mj decorate` — Stage 2 (styled variation)

```
mj decorate <dir>             # writes <dir>/decorated.png
```

`<dir>` holds `image.png` (the master from Stage 1, or any image to restyle) + `decorate.yml`, and
an **optional `style.png`** (passed as a second reference to steer the look). Nano Banana 2
reference edit. Example: `examples/decorate/`.

```yaml
# decorate.yml (DecorateSpec)
prompt: "..."                 # the style / theme / details to apply
keep_structure: true          # prepend a silhouette-preserving lead-in so decoration honours the master's form
model: "google:4@3"           # Nano Banana 2
width: 1024
height: 1024
```

With `keep_structure: true` the engine prepends: *"Keeping the same overall structure, silhouette,
proportions and layout, redraw this decorated in the following style and theme: …"* — so the
decoration honours the master's form instead of wandering off. References sent =
`[master]` or `[master, style]` when a `style.png` is present.

This **two-reference (subject + style)** pattern — master pins the structure, style.png pins the
look — is exactly the lever [Magic Themes](../roadmap.md#magic-themes) would automate across every
venue with one shared style-reference image.

---
Related: [prop](prop.md) · [Nano Banana](../nano-banana.md) · [roadmap → Magic Themes](../roadmap.md#magic-themes)
