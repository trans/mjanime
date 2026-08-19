# `mj matte` — background removal (3 tiers)

General background removal for **arbitrary images** (as opposed to `mj prop`, which keys a known
solid bg). Local-first, API fallback.

```
mj matte <image> [out.png] [--local N] [--global N] [--feather N]   # Tier 1 (default)
mj matte <image> [out.png] --isnet [--model <onnx>]                 # Tier 2
mj matte <image> [out.png] --runware [--rw-model <AIR>] [--alpha-matting]  # Tier 3
```

Any input format (PNG read directly; otherwise transcoded to a temp PNG via ImageMagick). Default
output is `<image>-matte.png`.

> **The big lesson:** even high-end AI matting struggles on complex scenes (night skies, reflective
> floors, bright walls reading as background). Wherever possible, **generate the subject as a
> [prop](prop.md) on a solid bg instead** so you never remove a background. Use `matte` only when
> you're stuck with an existing scene image.

## Tier 1 — procedural (default, pure Crystal, no API)

Flood-fill the connected border background. Best on **simple / near-uniform** backgrounds
(synthetic mallet-on-noisy-offwhite scored IoU 0.981, no halo). Fails on cluttered photos.

- Reads a **border-median seed** colour (robust to a subject touching an edge).
- Multi-source BFS from the border: a neighbour joins the bg iff it's within **`--local`** of the
  current pixel (follows gradients) **and** within **`--global`** of the seed (hard cap that stops
  the fill entering the subject). A subject that *shares* the bg colour but isn't connected survives.
- **`--feather`** dilates the bg inward first (so the soft edge falls inside the subject, killing the
  halo), then box-blurs the alpha. Followed by despill + alpha-bleed (same fringe defence as the
  [prop keyer](../techniques.md#prop-keying--how-the-transparent-cut-works)).
- Defaults: `--local 20`, `--global 70`, `--feather 2`. Prints the seed colour and % removed.

## Tier 2 — `--isnet` (local neural)

Local neural matting via **IS-Net** through an ONNX Runtime C shim. Handles centered-facade scenes
well; struggles with bright walls / reflective floors.

- Resizes to 1024², normalises `channel/255 − 0.5`, runs the model, min-max normalises the score map,
  bilinear-upsamples to a full-res alpha, then alpha-bleeds.
- Model: default `~/.u2net/isnet-general-use.onnx` (override `--model <path>`). IS-Net is a
  lightweight CNN (171MB, ~6s CPU) — it won the model bake-off (u2net erased a thin mast; BiRefNet
  variants OOM'd on CPU or wiped the image).

**Build & run prerequisites:**
- `just build` compiles the C shim (`src/native/mjonnx.c` → `.o`) which `dlopen`s
  `libonnxruntime` at runtime (mj links only `-ldl`; onnxruntime stays optional).
- Needs `onnxruntime-cpu` installed (header `/usr/include/onnxruntime/`, lib
  `/usr/lib/libonnxruntime.so`).
- **protobuf soname workaround** (active until protobuf 35.1 lands in the repos): onnxruntime links
  `libprotobuf-lite.so.35.1.0` but the system ships `.35.0.0` (same ABI major → a compat symlink is
  safe):
  ```sh
  ln -sf /usr/lib/libprotobuf-lite.so.35.0.0 ~/.local/lib/mj-compat/libprotobuf-lite.so.35.1.0
  LD_LIBRARY_PATH="$HOME/.local/lib/mj-compat:$LD_LIBRARY_PATH" mj matte img.png --isnet
  ```
  (Setting `LD_LIBRARY_PATH` from inside Crystal won't work — glibc caches it at startup; it must be
  set at exec, or use a system symlink. When protobuf 35.1 arrives: `pacman -Syu` and delete the
  symlink, no code change.)

## Tier 3 — `--runware` (cloud, hero images)

GPU-backed removal via Runware's `imageBackgroundRemoval` task. Zero setup, best quality for the
occasional hero image (recovers thin antennas / crisp fine lines the CNN blurs).

- `--rw-model <AIR>`: the removal model. **Premium = `bria:2@1`** (Bria RMBG-2.0, BiRefNet-based) —
  the clear best on hard images. Omit `--rw-model` to use Runware's default remover (RemBG-1.4,
  u2net-class — no better than local u2net).
- `--alpha-matting`: enable Runware's alpha-matting refinement (fg thresh 240, bg 10, erode 10).
- Needs `RUNWARE_API_KEY`.

## Choosing a tier

| Situation | Tier |
| --- | --- |
| Simple / near-uniform bg | Tier 1 (default) |
| Centered subject on a busy-ish bg, offline | Tier 2 `--isnet` |
| Hero image, thin detail must survive | Tier 3 `--runware --rw-model bria:2@1` |
| A cutout you'll reuse as an asset | any — the result feeds the [prop library](prop.md#the-prop-library) / [Diorama](diorama.md) palette |

---
Related: [prop](prop.md) · [techniques → keying](../techniques.md#prop-keying--how-the-transparent-cut-works) ·
[world](../world.md)
