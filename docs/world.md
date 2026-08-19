# The World — Silicon Circus & the day / night / pixel pipeline

> Why the tools exist. mj is the studio that produces art for **Silicon Circus**, a
> boardwalk game. Most of the hard-won recipes only make sense once you know what the
> art is *for*.

## Silicon Circus, in one paragraph

A seaside boardwalk carnival. By **day** the "real" venues are seen as **pixel art** —
mundane, ordinary, the everyday face of the place. At **dusk** the *projectors* switch on
and the boardwalk fades from the day image into a **photoreal, luminous "imaginary world"**
version of each venue. At **dawn** it fades back, and once the projectors shut off the
world **hard-cuts to pixel** again. There is also a game mode where **the world is
pixelating** — an epidemic radiating out from Silicon Circus itself. Time is running out
before everything turns into a pixel.

That premise is the reason every venue is authored in **three registers**, and the reason
we keep *multiple* pixel tiers instead of one.

## The three registers (per venue)

| Register | What it is | How it's used in-game |
| --- | --- | --- |
| **`real/…-day.png`** | Photoreal, day lighting, **fully lit and vibrant** | The daytime face of the projected world |
| **`real/…-night.png`** | Same building, **projectors ON** — glowing, floodlit, luminous | The dusk→dawn "imaginary world" reveal |
| **pixel** (`pixel-32`, `pixel-16`, `pixel-8`) | Hand-drawn-looking pixel art at several coarseness tiers | The mundane daytime look **and** the pixelating-world degradation stages |

Two transitions the assets must support:

- **Dusk / dawn crossfade** — `real/day` ⇄ `real/night`. Requires the two images to be
  **pixel-registered** (same canvas dims, same building footprint) so they cross-dissolve
  cleanly.
- **Day → pixel hard cut** — and the **pixelating game mode**, which steps a venue through
  **pixel-32 → pixel-16 → pixel-8** as coarser and coarser degradation. All tiers are kept
  on purpose; a coarser pixel is not "worse", it's a later stage of the apocalypse.

Because of both transitions, **pick ONE canonical dimension per venue** and generate day,
night, and every pixel tier at it, so all of them register.

> ⚠️ **The night image is NOT a dark night.** "Night" here means the projectors turned the
> imaginary world ON — it must read as **radiant / floodlit / glowing**, not moody-dark. See
> [night lighting](techniques.md#night-lighting--the-projection-reveal) for the balance.

> ⛔ **The pixel register is DRAWN as pixel art by the AI, never a procedural downscale of
> the photo.** A plain resize "looks almost like the original" — that is wrong. See the
> [pixel recipe](techniques.md#the-pixel-recipe).

## Pixel tiers

| Tier | Feel | Block-size cue (the "~Npx across" lever) |
| --- | --- | --- |
| **pixel-32** | Detailed **late-16-bit** — the current standard | simple subject ~340px; busy subject ~190px |
| **pixel-16** | Chunky **early-16-bit** | ~130px |
| **pixel-8** | Reserved for the coarsest degradation stage | (lower still) |

The block-size number is inverse to detail: **busier subjects need a LOWER number** to read
as unmistakably chunky (a dense marquee resists chunking at 320 but commits at ~190). See
[the pixel-chunk lever](techniques.md#the-pixel-chunk-lever).

## How a venue is produced (the winning workflow)

1. **Generate the venue as a PROP on a solid background** — never as a full scene you matte
   afterward. (`mj prop`, chroma/black bg → trivial distance-key.) This is the single most
   important lesson: *we do not remove complex backgrounds anymore* (see
   [background removal](tools/matte.md) for why even good AI matting struggles).
2. **Day master** — `mj prop`, prompt frames the concept as **real architecture / real
   materials**, on a solid chroma bg. Bake **unlit external light fixtures** into the day so
   they have something to switch on at night.
3. **Night relight** — copy the day `render.png` to be the night dir's `template.png` (the
   master *is* the reference → structure pinned), then `mj prop` with a "relight to night,
   keep EXACT building, all lights ON" prompt.
4. **Pixel tiers** — `mj pixelize` on the **day** master image, one run per tier with the
   [pixel recipe](techniques.md#the-pixel-recipe) at the tier's block-size cue.
5. **Register & place** — resize to the venue's canonical dims if needed; hand-finish base
   shadows / floor strips (distance-keying can't remove cast shadows).

## Asset map (cross-repo)

The **finished venue art does not live in this repo.** It lives in the game repo:

```
~/Projects/siliconcircus.lol/archive/media/boardwalk/used/venues/
  real/        <venue>-day.png   <venue>-night.png      (photoreal registers)
  pixel-32/    <venue>-pixel.png                        (detailed late-16-bit — standard)
  pixel-16/    <venue>-pixel.png                        (chunky early-16-bit)
  pixel-8/                                              (reserved)
  _wcfranks-prev/ , _venues-used-backup/                (backups — never overwrite blindly)
```

**Working files** (templates, renders, pixel.yml) live in the mj prop library:
`~/.local/share/mj/props/<venue>[-night|-p32|-p16]/`.

### Venue inventory (boardwalk v1 — all 11 have day + night + pixel)

digital-art-museum · world-of-words (WOW / "…Institute") · doghouse (poker parlor) ·
nicks (Christmas circus tent) · wcfranks (W.C. Frank's Arcade) · goldies (Goldie the
goldfish) · guest-services (has `-clean`/`-dingy`) · cattacula (Mistress Cattacula's tent) ·
bigtop · funhouse · piggy-bank · radio-hall.

Plus **beach backdrops** (day + night + pixel-32/16, `background: keep` — full frames, not
props) for the boardwalk to sit over with parallax, and **Christmas props** (tree, snowman)
for outside Nick's.

## Hard rule about the user's files

**Never delete or overwrite anything without asking** — especially the user's curated
cutouts and the `_*-backup` / `_*-prev` folders. Generated intermediates are fair game;
delivered art and originals are not. This rule exists because it was violated once. See
[feedback in the roadmap](roadmap.md#working-agreements).

---
Related: [techniques](techniques.md) · [Nano Banana](nano-banana.md) · [`mj prop`](tools/prop.md) ·
[`mj pixelize`](tools/pixelize.md) · [roadmap](roadmap.md)
