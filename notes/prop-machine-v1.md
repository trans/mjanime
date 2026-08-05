# The Prop Machine — 2D Prop Generator (v1)

_Built 2026-07-08. Turns a rough flat-colour template into a game-ready 2D prop with a transparent
background. Validated on `data/props/{barrel,plant,clown}-*.png` ("worked pretty damn well"). Source:
`src/models/prop_spec.cr`, `src/engine/prop.cr`, CLI `minanime prop <dir>`._

## What it does

Input: a **template** — a rudimentary flat-colour drawing of a subject (silhouette + a few feature
colour patches, ~5–8 colours). Output: **`prop.png`**, the subject painted in full detail with the
background keyed out to transparent, ready to drop onto a game scene.

It also writes **`render.png`**, the raw AI output on its solid background, so you can inspect what the
model actually drew before keying.

## The recipe (three steps)

1. **Paint on a known background.** Nano Banana (`google:4@1`, via `edit_references`) takes the template
   as a reference and paints the subject over a solid, named background colour (default black). The
   prompt must name that background ("…on a solid pure black background, nothing else in frame").

2. **Key on distance-from-background.** For every pixel, alpha ramps (smoothstep) from `0` when the
   pixel equals the background colour to `1` when it is far from it — measured as the max per-channel
   absolute difference (0–255). This is the generalisation of the old "black → transparent" trick: with
   a black background, distance-from-black is just brightness, so bright subject = opaque, black bg =
   transparent. But because it keys on *distance from a configurable colour*, it works for **any**
   background — which is what makes dark/black subjects possible (see below).

3. **(Optional) soften the edge.** A small box blur on the **alpha channel only** feathers the rim.
   `edge_blur: 2` is a good default when a crisp cut looks too hard against a scene.

No matting model, no green-screen chroma math, no strict silhouette fit — soft, distance-keyed edges
tolerate the fact that the AI drifts.

## The knobs (`prop.yml` / `PropSpec`)

| Field         | Default        | What it does |
|---------------|----------------|--------------|
| `prompt`      | —              | Subject description; **must name the background colour** you set below. |
| `background`  | `[0, 0, 0]`    | RGB colour to render on and key out. Match it to the prompt. |
| `key_low`     | `4`            | Distance below this → fully transparent (kills bg haze/compression noise). Raise to ~26 to swallow the model's noisy-magenta speckle. |
| `key_high`    | `28`           | Distance above this → fully opaque. Lower keeps faint thin details (ropes, leaves); raise for a cleaner cut or a see-through subject (spring ~110). |
| `edge_blur`   | `0`            | Px radius of alpha-only box blur. `0` = crisp. |
| `despill`     | `true`         | Colour-unmatte partial-alpha edge pixels: recover F = (C−(1−a)·B)/a, stripping bg tint from anti-aliased edges. |
| `defringe`    | `true`         | Subtract residual bg-chroma cast from the `alpha>0` body/edge. Self-limiting (only fires where a pixel leans toward the bg hue). |
| `defringe_band` | `0`          | `0` = whole image; `N` = confine defringe to within N px of transparency (edge shell) — for subjects that legitimately contain the key hue. |
| `alpha_bleed` | `true`         | "Solidify": flood transparent pixels with nearest subject colour so downscalers can't resurrect the key colour (see 2026-08-05 note). |
| `model`       | `google:4@3`   | Nano Banana 2 (`4@1` deprecated/weak, `4@2` = Pro). |
| `width`/`height` | `1024`      | Render size. |
| `tags`        | `[]`           | Free-form tags flowed into the library manifest (`index.json`) for tag-based lookup. |

## The three edge considerations (from the wiring request)

- **"Would medium gray give better edges than black?"** Not on its own — edge quality comes from
  *contrast between subject and background*, not from the background being neutral. What actually
  matters is that the background is far, in colour space, from the subject's edge pixels. So instead of
  picking one magic colour, the background is **configurable** and you choose it to contrast the
  subject. Black is the right default for the bright, saturated props these tend to be.

- **"An alternative for when the thing I'm making is black."** This is the real payoff of
  distance-keying. If the subject is black/dark, a black background can't be distinguished from it —
  so render on a **contrasting** background instead and name that colour in the prompt. The keyer
  measures distance from whatever colour you set. But not every contrasting colour is equal: see
  **Choosing a background** below — for a dark subject, chroma-green beats white.

- **"Adding a slight blur to the edges — how feasible?"** Very. It's `edge_blur`, a separable box blur
  applied to the alpha channel alone (RGB untouched), so it only softens the cut-out silhouette, never
  the art. Cheap and deterministic. Comparison on the barrel (over bright green to expose fringe):
  `blur0` crisp → `blur2`/`blur4` progressively feathered, with no dark halo at any setting.

## Choosing a background

The background must sit far, in colour space, from **every** part of the subject — not just its
silhouette edge, but any interior feature too. The failure mode is the reverse of keying: a subject
feature that lands *near* the background colour gets keyed transparent, punching a hole.

| Subject | Use | Why |
|---------|-----|-----|
| Bright / saturated (barrel, plant, clown) | **black** `[0,0,0]` (default) | Nothing bright is near black; keys clean. |
| Dark / black (cauldron, cat, bat) | **chroma-green** `[0,255,0]` | Black is maximally far from green, and subjects rarely contain green. |

**Validated finding (cauldron, 2026-07-08):** the same black cauldron was rendered on white and on
green (`data/props-test/cauldron-{white,green}/`).

- **Green:** body, legs, orange potion, and even the wispy steam all keyed opaque and clean — no
  fringe, no holes.
- **White:** the body keyed fine, but the render's near-white steam/glow sat too close to the white
  background and got keyed away — the steam vanished and a pale halo was left around the rim. **White
  only works if the subject has no light highlights.**

So for a dark subject, prefer **green over white**. Same command either way; only `background` and the
prompt's named colour change.

Not yet tested: **green spill** onto genuinely *soft* edges (fur, a bat's wing membrane) — the cauldron
had hard cartoon edges. If a fuzzy dark subject picks up a green rim, that's the case to revisit.

## Important caveat: template ≠ silhouette

The template is a **rough reference** for the subject and its size/placement — it is **not** a cutter.
The model paints outside the lines. In testing the props stayed close to the template's general size but
regularly exceeded its exact boundary. That is why the prop is cut out of the **render**, never the
template. If you need a prop that fits an *exact* footprint, that is a separate, harder problem (strict
silhouette constraint) not solved here.

## API (this is a library, not just a command)

The CLI is a thin wrapper. Everything is callable from Crystal:

```crystal
spec = Minanime::PropSpec.from_yaml(File.read("prop.yml"))
# ...or build it in code:
spec = Minanime::PropSpec.from_yaml(%(prompt: "a red barrel on a solid black background"))
spec.background = [0, 0, 0]
spec.edge_blur  = 2

client = Minanime::RunwareClient.new(Minanime::Config.runware_api_key)

# From a template file OR from PNG bytes (fully in-memory, no disk I/O):
result = Minanime::Prop.generate(client, "template.png", spec)
result = Minanime::Prop.generate(client, template_bytes, spec)

result.render  # StumpyPNG::Canvas — raw AI output on the background
result.prop    # StumpyPNG::Canvas — keyed, transparent

# Pure, no network: key any render you already have (e.g. from another generator):
prop = Minanime::Prop.key_out(some_canvas, spec)
```

- `Prop.generate` returns a `Prop::Result` record (`render`, `prop`) of in-memory canvases.
- `Prop.key_out(render, spec)` is a pure function — no API call — so keying, threshold sweeps, and
  edge-blur experiments run offline on a render you already have.
- `PropSpec` is `YAML::Serializable`; construct from YAML or set fields directly.

## CLI

```
mj prop <name>            # resolve <name> inside the prop library root
mj prop <name> --rekey    # re-key only (no API call) — tune knobs against an existing render
mj prop path/to/dir       # explicit one-off dir (anything with a '/' is treated as a path)
```

Writes `render.png` (raw) and `prop.png` (transparent) into the prop's folder, and upserts a row
into the library manifest (see below). See `examples/prop/` for a working template + config.

## The prop library (storage, updated 2026-08-05)

Props live in a **self-contained, relocatable tree outside the repo** — one folder per prop —
so the library survives repo moves and maps cleanly onto a future TransFS/DataDungeon backend
(switching backends = repoint the root + write an adapter, not a rewrite).

- **Root** (`Config.props_dir`), precedence: `$MJ_PROPS_DIR` → `config.yml` `props_dir:` →
  `$XDG_DATA_HOME/mj/props` → `~/.local/share/mj/props` (the default).
- **Layout**: `<root>/<name>/{prop.yml, template.png, render.png, prop.png}`. `prop.yml` is the
  recipe (source of truth); `template.png`/`render.png` are regenerable provenance; `prop.png` is
  the deliverable. The `prop-` prefix from the old `data/prop-*` dirs is dropped — the folder name
  *is* the prop name.
- **Manifest**: `<root>/index.json`, auto-upserted on every build/rekey (`PropLibrary.record`).
  One row per prop: `name, tags, model, width, height, source_sha` (sha256 of `prop.yml`, so it
  changes when the recipe changes), `created` (preserved), `updated`. Rows sorted by name for
  stable diffs. This is the tag/provenance seam a tag-based (tqag) TransFS will index on.
- **Tags**: `PropSpec.tags` (a `tags: [..]` list in `prop.yml`) flow into the manifest — seed the
  metadata now so migration is a copy + adapter.

## Evidence

- `examples/prop/` — barrel end-to-end run (`template.png` → `render.png` → `prop.png`), keyed clean
  on black, verified over bright green with no fringe.
- `data/props/{barrel,plant,clown}-{template,render,prop}.png` — the original three-prop validation.

## Fringe defence, layered (updated 2026-08-05)

Chroma-key fringe is fought in four stacked passes; each cleans a different pixel population:

1. **High `key_high` + `key_low` floor.** `key_high` keeps thin/see-through detail opaque (spring
   coils ~110); `key_low` ~26 cuts the model's noisy-magenta bg speckle to fully transparent.
2. **`despill` (unmatte).** For partial-alpha edge pixels, recover the true foreground
   `F = (C − (1−a)·B) / a` — strips the bg tint baked into anti-aliased edges.
3. **`defringe`.** On the `alpha>0` body/edge, subtract the *shared* chroma excess (magenta = R&B
   jointly over G). Self-limiting: greys the tint, spares warm/neutral subject colour. `defringe_band`
   optionally confines it to the edge shell for subjects that legitimately contain the key hue.
4. **`alpha_bleed` ("solidify") — the downscale fix.** Keying only zeros the background's *alpha*;
   its *colour* stays in the RGB of the transparent pixels. Invisible in an alpha-correct view, but a
   **non-premultiplied downscale** (OS thumbnailers, GPU mipmaps, naive resamplers) blends that hidden
   magenta back into the subject — so the key hue *reappears as a pink fringe only when the prop is
   shrunk*, worst on reflective/metal props. Fix: flood every transparent pixel with its nearest
   *subject* colour (alpha kept 0) via multi-source BFS from the opaque pixels outward
   (`Prop.bleed_alpha!`). Distinct from defringe: defringe cleans `alpha>0`; bleed cleans the
   `alpha==0` region that mipmapping resurrects. (Origin: Thomas noticed the spring went pink only in
   the small thumbnail.)

**`mj prop <dir> --rekey`** re-runs *only* the keying step on an existing `render.png` — no API call —
for tuning any of the knobs above against a render you already like.

- Evidence: `data/prop-spring/` (see-through steel coil) and `data/prop-gear/` (worn cast cog).
  Both verified: zero magenta-leaning pixels at any threshold, and zero magenta in a 48px downscale
  (the operation that used to bring the pink back).
