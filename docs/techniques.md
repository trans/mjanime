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

8. **`despeckle`** (default `0` = off) — drops stray opaque islands smaller than N px. See
   [the background is not flat](#the-background-is-not-flat--despeckle) below for why they exist.

**Layered fringe defence** = chroma bg + high `key_high` + despill + defringe + alpha_bleed.

**Background choice:** black (`[0,0,0]`) keys **bright** subjects cleanly; for a **dark** subject
use white `[255,255,255]` or chroma green `[0,255,0]` / magenta `[255,0,255]`. **Name the bg colour
in your prompt too**, and add *"floats isolated, no ground / no floor / no people"* (never "on the
ground" — it adds a floor).

**`--rekey`** re-runs *only* the keying step on an existing `render.png` (no API call) — the way to
tune `key_low`/`key_high`/`blur`/`despill`/`defringe`/`bleed`/`despeckle` against a render you like.

### The background is not flat — despeckle

**The model never gives you the key colour you asked for, and never gives you it flat.** Measured on
an empty corner of a raw `google:4@3` render whose prompt demanded solid `#FF00FF`:

```
requested   255,   0, 255
delivered   245,  40, 244      green swinging ±10, in visible 8–16px blocks
distance from the requested colour: 42.6
```

Two consequences, and the first is the one that will bite you:

- **That distance exceeds a typical `key_high`.** With `key_high: 40` and `auto_background: false`
  the entire background sits mid-ramp and keys to *partial alpha*. **`auto_background: true` is not
  a convenience, it is load-bearing** — it samples what actually arrived instead of trusting the
  swatch. Only turn it off when the corners are genuinely not background (the bunker frame, where
  the corners are concrete), and then expect to tune `key_low`/`key_high` by hand.
- **The perturbation is structured, not uniform noise.** It drifts across the frame — green measured
  38 in one corner and 57 in another on the same image — so pixels near the threshold resolve
  inconsistently and leave crumbs, most visibly as a **dust strip along one edge**. That strip is
  what silently inflates an alpha bounding box: for a prop pinned by bbox (every boardwalk venue) it
  reads as extra width and a lower contact point, which is a placement bug, not a cosmetic one.

**Do not fix this by raising `key_low`.** It works on solid-edged subjects and destroys feathery
ones, because thin detail *is* small:

| subject | `key_low` 4 → 16 | `despeckle: 64` |
| --- | --- | --- |
| tent facade | 5 → 3 islands, −0.5% subject | 5 → **2**, subject untouched |
| winter park | 13 → 12 | 13 → **6**, subject untouched |
| palm tree | 39 → **62** islands, −3.6% subject | 39 → **1**, subject untouched |

**`despeckle` alone is not enough, and this is the part that breaks "crop to content".** The
artefacts collect hardest at the very frame edge, where they form strips that are **1–2px tall but
hundreds of px wide**. Measured areas of 254 and 297 px — far above any sane despeckle threshold, so
despeckle cannot touch them. One such strip pins the alpha bounding box to the whole frame, and every
crop-to-content, auto-trim or bbox pin silently becomes a no-op:

| prop | alpha bbox before | after `edge_guard: 2` |
| --- | --- | --- |
| laser pavilion | `1200x895+0+0` (whole frame) | `948x837+250+57` |
| photobooth | `896x1200+0+0` (whole frame) | `755x1082+139+116` |
| rowboat | `1024x1023+0+0` (whole frame) | `1013x893+3+129` |

**`edge_guard`** (default `2`) zeroes the alpha of the outermost N px all the way round, and runs
*before* despeckle — clearing the border also snaps long edge strips into short stubs that despeckle
then removes for free. It is safe by default because every prop is prompted to leave a clear margin,
so there is nothing at the border to lose. Set it to `0` only for something that deliberately bleeds
off the edge.

`despeckle` labels 8-connected opaque islands and zeroes any under N px, running **after** defringe
and **before** `alpha_bleed` (bleed floods transparent pixels with subject colour, so a speck left
standing would seed a halo around itself and survive). In every case above the main blob area came
out **byte-identical** — it removes dust and never subject.

Start at `despeckle: 64`. Raise it if crumbs survive; **leave it off** for subjects whose real detail
is genuinely tiny and disconnected — scattered bulbs, sparks, snow flecks, distant birds — since it
cannot tell those from dust.

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

## When the subject IS the key colour

A distance-from-background key is per-pixel, so it cannot tell a black backdrop from black paint on
the subject. Measured on the graveyard gate pier, rendered on pure black:

| sample | RGB | distance |
| --- | --- | --- |
| backdrop | (0,0,0) | 0 |
| gargoyle body | (8,14,14) | 14 |
| base plinth stone | (20,12,10) | 20 |
| shaft edge in shadow | (0,0,0) | **0** |

At `key_low: 4, key_high: 26` the gargoyle sat at ~40% alpha and the plinth dissolved. Dropping to
`key_low: 1, key_high: 10` recovered every one of those — the backdrop really is 0, so the window
only has to clear it, not clear the subject's own shadows. **On a pure-black render, key 1..10, not
4..26.** Glowing subjects (candles, pumpkins, ghosts) are the exception: their bloom wants the wider
ramp, and they carry no near-black interior to lose.

The shaft edge at distance 0 is unrecoverable by any threshold — the information is spatial, not
chromatic. `notes/graveyard/seal.py` closes the silhouette, floods the background in from the
borders, and forces everything unreachable from outside to full alpha. It works, but **it will seal
lacy detail**: on the pier it filled the real gaps between ivy leaves with opaque black. Prefer a
correct key window; reach for sealing only when a solid-bodied subject is genuinely punctured.

## A prop's ground line is not always its bottom edge

Props are seated by putting the bottom of the alpha content box on the floor, which is right for a
headstone and wrong for anything drawn with a spreading base. The graveyard's framing tree has an
exposed root flare: its opaque width peaks 12% up the silhouette (537px) and only resolves to trunk
width (~220px) by 20%. Seating its lowest root tip on the floor hung the whole trunk in the air.

Measure the width profile, put the ground line where the flare meets soil — 15% up for that tree —
and let the tips below sink into the earth. `place(..., base=0.15)` in the haunted-house project's `build/scene.py`.
