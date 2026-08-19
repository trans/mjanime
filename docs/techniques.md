# Techniques & lessons — the recipes that actually work

The distilled craft behind mj's art. These are empirical: earned over many rolls, corrections,
and dead ends. Where a recipe has a verbatim prompt fragment, it's reproduced so you can reuse it.

- [The pixel recipe](#the-pixel-recipe)
- [The pixel-chunk lever](#the-pixel-chunk-lever)
- [Prop keying — how the transparent cut works](#prop-keying--how-the-transparent-cut-works)
- [Templates — a rough reference, not a cutter](#templates--a-rough-reference-not-a-cutter)
- [Night lighting — the projection reveal](#night-lighting--the-projection-reveal)
- [Style vocabulary — words that sabotage](#style-vocabulary--words-that-sabotage)
- [Backdrop tiling & scene stitching](#backdrop-tiling--scene-stitching)
- [ImageMagick cheatsheet (safe commands)](#imagemagick-cheatsheet-safe-commands)

---

## The pixel recipe

> ⛔ **The pixel register is DRAWN as pixel art by the AI. It is NEVER a procedural downscale
> of the photo.** If a pixel comes back looking photographic, the generator **under-stylized** —
> re-roll with a stronger prompt. Do **not** fall back to `-resize` / `snap`.

Nano only *actually* pixelates when the prompt gives it two things:

1. **A resolution cue** — tell it the pixel grid must be visible on every surface:
   > *"the image MUST be built from distinctly visible blocky SQUARE PIXELS with hard
   > stair-stepped edges, as if drawn at ~220px across then enlarged, so the pixel grid is
   > obvious on every surface"*
2. **The "artist draws it" framing** (the user's tip — a big help):
   > *"a video-game pixel artist DRAWING it, not pixelating the reference photo"*

Plus a **rich dithered palette**, and — the repeated fix — *"dither the FLAT surfaces too
(no smooth gradients anywhere)"*, or flat tent canvas / sky come back as smooth gradients.

Without the resolution cue you get a smooth illustration or a roughed-up photo — the single most
common failure. A *"preserve the detail"* clause **fights** the redraw and makes it worse; keep
the prompt **pushing** the style.

`mj pixelize` already appends a **text-exception** so signage stays legible (lettering is
pixelated straight, not redrawn as mush) — you don't add that yourself.

**Rules:** no game/IP names in prompts (user rule). No procedural snap as "the look".

## The pixel-chunk lever

The **"~Npx across"** number in the resolution cue is the coarseness dial — and it's **inverse
to detail**:

| Subject | Chunky (pixel-16-ish) | Standard (pixel-32, late-16-bit) |
| --- | --- | --- |
| **Busy / detailed** (a dense marquee, W.C. Frank's) | ~190px | ~240px |
| **Simple** (beach, open sky) | ~130px | ~340px |

A busy venue **resists chunking**: ~320px reads as "not pixel enough", ~240 is still fine,
**~190px** finally reads as unmistakable chunky pixel while keeping the marquee legible. Simple
subjects can go coarse (low pixel count) without turning to mush. **When in doubt for a busy
subject, lower the number.**

---

## Prop keying — how the transparent cut works

`mj prop` renders the subject on a **solid known background**, then cuts it out by
**distance-from-background-colour** (not a hard-coded black→transparent). This is why a
**dark/black subject works**: render it on a contrasting bg (white or chroma green/magenta)
and it keys just as cleanly. The algorithm (`Prop.key_out`, verified against source):

1. **Background colour** — with `auto_background: true` (prop default), it **samples the actual
   rendered corners** (average RGB of four corner squares), *not* the colour you asked for. The
   model rarely paints the exact bg requested (a `#FF00FF` request came back ~`[194,68,168]`),
   so sampling the real corner is what makes chroma keys work at all.
2. **Distance** — per pixel, the **max per-channel** absolute difference from the bg (Chebyshev,
   not Euclidean).
3. **Alpha ramp** — `key_low..key_high` (0–255) with a smoothstep: below `key_low` = fully
   transparent, above `key_high` = fully opaque, smooth between. **Lower `key_high`** keeps faint
   thin detail (leaves, ropes); **raise it** for a cleaner cut or to absorb a lit/gradient bg.
4. **`edge_blur`** — optional box blur on the alpha channel only, to soften the edge.
5. **`despill`** (default on) — colour-unmatte edge pixels: recover true foreground
   `F = (C − (1−a)·B) / a`, stripping the bg tint from anti-aliased edges. Only touches partially
   transparent pixels.
6. **`defringe`** (default on) — subtract residual bg-**chroma** cast (magenta/green halo) that
   clings to sub-pixel detail. Self-limiting: it greys out the shared chroma excess but leaves
   warm/neutral subject colour alone (does nothing on a neutral bg). `defringe_band` confines it
   to an N-px edge shell — set 1–3 **only** if the subject legitimately contains the key hue;
   otherwise 0 (whole image) is best for see-through detail like rigging.
7. **`alpha_bleed` / "solidify"** (default on) — **the fringe-resurrection fix.** Keying zeros the
   bg's *alpha* but leaves its *colour* in the transparent pixels' RGB. Non-premultiplied
   downscalers (OS thumbnailers, GPU mipmaps) blend that hidden colour back in, so the key hue
   **reappears as a fringe only when the prop is shrunk** (worst on reflective/metal props). This
   floods every transparent pixel with the nearest subject colour (alpha stays 0) so there's
   nothing left to resurrect. Harmless in alpha-correct rendering.

**Layered fringe defence** = chroma bg + high `key_high` + despill + defringe + alpha_bleed.

**Background choice:** black (`[0,0,0]`) keys **bright** subjects cleanly; for a **dark** subject
use white `[255,255,255]` or chroma green `[0,255,0]` / magenta `[255,0,255]`. **Name the bg colour
in your prompt too**, and add *"floats isolated, no ground / no floor / no people"* (never "on the
ground" — it adds a floor).

**`--rekey`** re-runs *only* the keying step on an existing `render.png` (no API call) — the way to
tune `key_low`/`key_high`/`blur`/`despill`/`defringe`/`bleed` against a render you like.

**What keying can't do:** remove **cast shadows** on the bg (a dark shadow is "far from green" =
opaque) or the floor/light-pool strip a night render adds at the base. Those need a spatial trim —
the user handles them by hand in GIMP.

> **Meta-lesson (the whole reason props exist):** *"I will never mess with background removal
> again — even high-end AI struggles."* Generate venues **as props on a solid/known bg** so you
> never remove a complex background. See [`mj matte`](tools/matte.md) for when you're stuck with
> an existing scene.

---

## Templates — a rough reference, not a cutter

The `template.png` is a **rough reference** for subject + size/placement — **NOT** a strict
boundary. Nano paints outside the lines; the prop is cut from the **render**, never the template.
(Exact-footprint fit is a separate, unsolved problem — see [roadmap](roadmap.md).)

Hard-won template rules:

- **Bright/coloured template → flat cartoon output.** The model copies the template's *style*.
  Use a **neutral grey massing** template (no colours, no baked text) → the model ignores style
  and obeys the prompt. Bonus: grey leaks into the material (grey template → grey concrete).
- **Organic / ornate subjects: use NO drawn template.** Nano traces silhouettes, so a boxy
  template → a boxy building. Feed a **blank chroma-green canvas** (the edit model needs *an*
  image) and let the prompt drive. Reserve drawn templates for genuinely geometric subjects (a
  brutalist box).
- **Surgical edits = edit-from-reference.** To fix one word or relight without reseeding the whole
  building, copy the render to be the new `template.png` and prompt *"keep EVERYTHING identical,
  change ONLY <this>"*. Back up `render.png → render-v1.png` first.

---

## Night lighting — the projection reveal

**Night = the projectors switch the imaginary world ON.** The night image must read as
**radiant / glowing / floodlit**, NOT a dark realistic night. A "deep night ambience / moody"
prompt *darkens* the exterior — backwards, it breaks the projection effect.

But it's a **tightrope** (the user has corrected this repeatedly):

- **Too dark** → looks *closed*, a black silhouette / a back-alley at 3am.
- **Too bright** → the lit signs/bulbs stop reading as "lit"; it just looks like **daytime**.
- **Target** = exterior dimmed to **EVENING**, structure still clearly visible and colorful, with
  the **marquee / bulbs / neon POPPING** against that dim. Keep dark in the recesses (archways,
  eaves, interior corners) so the emissive elements have something to contrast against.

Recipe that works:

1. **Bake UNLIT external light fixtures into the DAY** (bulbs / marquee / neon / lanterns /
   under-valance colored bulbs). Venues with only internal window-glow just *dim* at night = a weak
   reveal. Day and night must share the same fixtures.
2. **Relight** from the day render (day render → night dir's `template.png`), prompt:
   *"Relight at NIGHT, keep the EXACT building, all bulbs GLOW; the structure is NOT pitch dark /
   NOT a black silhouette — it's EVENING, still washed by warm ambient light from NEARBY boardwalk
   lamps & lit venues, so its colors stay VISIBLE and rich, only softly dimmed; the glowing bulbs
   POP against the dimmed-but-colorful tent."*

The **"lit by the neighbors"** framing is the key to *evening-not-3am*. An emissive element
(a lamp) must be told to *"GLOW FROM WITHIN like a paper lantern, internal light through a
translucent shell, must NOT be dark"* or it renders dark.

**Reusable reveal elements:** *under-valance multicolor lights* (rows of colored bulbs peeking from
under a scalloped awning) reveal beautifully. **Future idea:** at night make a circus tent's colored
**stripes** glow like **neon tubing** — the stripes become the light source (probably beats bulbs;
native to a tent).

**Process note:** *try-and-SEE before rewriting the prompt.* Look at a result first; don't jump to
editing the prompt prematurely.

---

## Style vocabulary — words that sabotage

Some words quietly wreck a realistic render (the user corrected each of these):

| Avoid | Because | Use instead |
| --- | --- | --- |
| `photorealistic` | banned by the user | **`realistic image`** |
| `illustration` | → cartoony | describe real materials |
| `fantasy` | → cartoony | concrete architectural detail |
| `boardwalk` (as a style word) | grimes / dirties it | name the specific structure |
| `small` / `little` (repeated) | cramps the venue, shoves interior detail out | describe scale positively / "deep explorable interior" |
| enumerated interior lists ("rows and rows of…") | shoves objects outside; invents false signage | name the ONE focal piece only |

For architecture, frame art influences as the building's **physical decor** ("a carved relief,
framed panels, a real sculpture") rendered as *"real architectural photograph, real materials, NOT
flat / cartoon / vector"* — otherwise "photorealistic" gets outvoted by "pop-art / silkscreen".

Also: a **venue is a BOARDWALK BRANCH, not the grand HQ** — match the modest boardwalk-stall scale
and vernacular of its neighbors.

---

## Backdrop tiling & scene stitching

Two related problems, one solved-ish and one still open.

### Backdrop tiling (the flip-glue seam)
A boardwalk backdrop that won't tile fails on the deck's **HORIZONTAL vanishing point**, *not*
"perspective" in general. The fix: **kill the horizontal convergence** — planks parallel (VP at
infinity), or best, a **flat tileable plank TEXTURE projected in-engine like a Mode-7 floor**. Then
it tiles, scrolls, and still looks like it has depth. (Cross-planks are wrong — "that's not how
boardwalks are built".) Deck-horizon stitching is a **niche worst-case**; ~80% of stitches
(jungle/forest/sky) have no such landmine.

### Scene stitching (connecting two scenes into a panorama)
Retried with Nano Banana 2 — big progress on half the problem. **Frame the connector as a FLAT,
ORTHOGRAPHIC 2D SIDE-SCROLLING BACKGROUND TILE and LOCK THE CAMERA**:
> *"same flat straight-on side view, NO perspective / vanishing point / step-back / zoom /
> rotation, same scale + eye level, deck planks same size/alignment (don't re-tile), lines level
> across, NO new foreground rail, NO stray objects."*

This fixes the flatness/camera problem (Nano's instinct is to paint a nice *scene* with its own
vantage). Generate taller (4:3, e.g. `1200×896`) to get vertical zoom-room, align the deck/water
lines, then crop 16:9.

**Still open — the Seamstress:** *bridging two DIFFERENT scenes* (content + style) across one tile.
The connector tends to just extend one side and ignore the other's style. See
[roadmap](roadmap.md#the-seamstress-problem) and `notes/connect-and-seamstress-v1.md`.

---

## ImageMagick cheatsheet (safe commands)

Snap/resize and matte-measurement commands that are known-safe (and one that isn't):

```sh
# Resize keyed output to a venue's canonical dims (photoreal):
magick in.png -resize 1456x816! out.png
# Resize a PIXEL asset — nearest-neighbour so it stays crisp:
magick in.png -filter point -resize 1456x816! out.png

# Composite a transparent cutout onto chroma green (to feed a relight as template.png):
magick in.png -background 'rgb(0,255,0)' -flatten template.png

# Clean faint edge HAZE from a generated cutout (floor sub-25% alpha):
magick f.png -channel A -level 25%,100% +channel out.png     # ✅ SAFE

# Measure the true subject bbox on an alpha-bled cutout:
magick f.png -alpha extract -threshold 20% -trim info:        # ✅ correct
```

> ⚠️ **NEVER `-black-threshold` on the alpha channel** — it **wiped two files** whose max alpha was
> 0.9999 down to a 1×1 transparent pixel. Use `-level 25%,100%` instead.
> ⚠️ **`%@` (RGB-trim) bbox is bogus on alpha-bled cutouts** — transparent areas carry bled RGB, so
> RGB-trim reports the full frame. Always measure via `-alpha extract -threshold N% -trim`.
> ⚠️ Only run cleanup on **mj-generated files**, never on the user's originals — keep a guarded
> whitelist.

---
Related: [world](world.md) · [Nano Banana](nano-banana.md) · [`mj prop`](tools/prop.md) ·
[`mj pixelize`](tools/pixelize.md) · [roadmap](roadmap.md)
