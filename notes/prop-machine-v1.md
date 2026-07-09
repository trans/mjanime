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
| `key_low`     | `4`            | Distance below this → fully transparent (kills bg haze/compression noise). |
| `key_high`    | `28`           | Distance above this → fully opaque. Lower keeps faint thin details (ropes, leaves); raise for a cleaner cut. |
| `edge_blur`   | `0`            | Px radius of alpha-only box blur. `0` = crisp. |
| `model`       | `google:4@1`   | Nano Banana. |
| `width`/`height` | `1024`      | Render size. |

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
minanime prop <dir>
```

`<dir>` holds `template.png` + `prop.yml`. Writes `render.png` (raw) and `prop.png` (transparent).
See `examples/prop/` for a working template + config.

## Evidence

- `examples/prop/` — barrel end-to-end run (`template.png` → `render.png` → `prop.png`), keyed clean
  on black, verified over bright green with no fringe.
- `data/props/{barrel,plant,clown}-{template,render,prop}.png` — the original three-prop validation.
```
