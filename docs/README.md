# mj docs

The mj wiki — how the tools work, the techniques that actually work, and the world they serve.
(Auto-generated Crystal API docs live separately under `docs/api/`.)

## Start here

- **[The World](world.md)** — Silicon Circus and the day / night / pixel pipeline. *Read this first:
  most recipes only make sense once you know what the art is for.*
- **[Techniques & lessons](techniques.md)** — the pixel recipe, prop keying, night lighting, style
  vocabulary, tiling/stitching, the ImageMagick cheatsheet. The distilled craft.
- **[Nano Banana](nano-banana.md)** — the image model mj leans on: versions, fixed dims, statelessness,
  prompt craft.
- **[Roadmap](roadmap.md)** — Magic Themes (the goal), open problems (the Seamstress, footprint
  alignment), unwrapped threads, and the working agreements with the user.

## Tools

Full CLI reference index: **[tools/README.md](tools/README.md)**.

| Tool | What it does |
| --- | --- |
| [`mj prop`](tools/prop.md) | Rough template → Nano render on solid bg → keyed transparent prop |
| [`mj pixelize`](tools/pixelize.md) | AI pixel-art restyle (8/16-bit), optional transparency + snap |
| [`mj matte`](tools/matte.md) | Background removal — procedural / IS-Net / Runware tiers |
| [`mj strip`](tools/strip.md) | Row of images → one long seamless panorama |
| [`mj base` / `mj decorate`](tools/base-and-decorate.md) | Template → structural master → styled variation |
| [`mj sfx`](tools/sfx.md) | Reference sound → procedural Web Audio recipe |
| [Diorama / backdrop / webp](tools/diorama.md) | Compose props+backdrops into parallax scenes and play them |
| [`mj bus`](tools/bus.md) | Serve the image tools on the Arcana bus |

## The three big lessons (if you read nothing else)

1. **Generate subjects as [props on a solid bg](tools/prop.md)** — don't matte complex scenes. Even
   high-end AI background removal struggles.
2. **Pixel art is [DRAWN by the AI](techniques.md#the-pixel-recipe), never a procedural downscale.**
   Under-stylized = strengthen the prompt's resolution cue, don't reach for `snap`.
3. **[Night = the projectors ON](techniques.md#night-lighting--the-projection-reveal)** — radiant and
   floodlit, not a dark night. It's a tightrope between "daytime" and "3am".

---
These docs consolidate lessons that previously lived only in Claude's private memory and scattered
`notes/`. The long-form investigations still live in `notes/` (`connect-and-seamstress-v1.md`,
`inpainting-analysis-v1.md`, `prop-machine-v1.md`, `diorama-plan.md`, `google-nano-banana-*.md`).
Day-to-day loose ends live in `TODO.md`.
