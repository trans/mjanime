# Diorama, backdrops & webp — compose and play

The **compose → play** stage after mj's generators: props + backdrops → a parallax depth-layer
scene → played with drift or walk-through. Served by `mj serve` (web app, port **21683**).

## Diorama

A **diorama** is a set of image planes placed at real depths (a scene). The backdrop is oversized so
parallax drift never reveals an edge; alignment is by horizon (baked eye-level → world y=0), scale
(the FOV knob), and floor (grounds seated props). Built on three.js (r170, vendored).

Routes (`MJ::Diorama.register`, slug `diorama`):

| Route | Purpose |
| --- | --- |
| `GET /diorama` | The editor (full nav chrome) |
| `GET /diorama/play/:name` | Chrome-less **embeddable** player (drift + walk-through) |
| `GET /diorama/assets.json` | Palette: props (`cut:true`) from the prop library + backdrops (`cut:false`) |
| `GET /lib/props/:name` | Serve a prop image — **prefers `prop.webp`** over `prop.png` |
| `GET /lib/backdrops/:name` | Serve a backdrop — prefers `.webp` |
| `GET/PUT/DELETE /diorama/scenes/:name` | Scene CRUD (+ `GET /diorama/scenes` to list) |

Scenes are saved as `<name>.json` under `Config.scenes_dir` (`~/.local/share/mj/scenes/`) — the
editor's own export shape, self-describing, with an open `meta:{}` on scenes and layers (portable
format). `SceneLibrary.safe_name` sanitises names so a scene can't escape the library root; the
`/lib/…` routes use a `within?` path-traversal guard.

### Layer fields

```json
{ "src": "/lib/props/grave-crow", "w": 1024, "h": 1024,
  "x": 1.4, "y": 0.0, "z": -2.5, "scale": 1.1,
  "horizon": 0.5, "shadow": false, "billboard": 80, "flipX": false, "meta": {} }
```

`scale` is the **image** height in world units (width follows from `w/h`), so a prop with
transparent padding needs `scale` scaled up by `img_h / content_h` for its *content* to come out
the size you meant. `z` is real depth, so a 1.1 m headstone stays `scale: 1.1` at every distance —
the camera does the shrinking.

| Field | Effect |
| --- | --- |
| `billboard` | Degrees the card may **turn to face the camera**, clamped to ±this. `0` (default) = a fixed pane. Cards are flat, so a subject that reads wrong in profile — a crow, a gargoyle, a roughly symmetric shrub — can keep looking at the viewer through the drift. Architecture should stay at 0. |
| `flipX` | Mirror the card horizontally, so **one prop serves both sides** of a symmetric composition (left and right gate piers, framing trees). Materials render `DoubleSide` so a mirrored or turned card never culls. |

Turning a card toward the camera makes its projection **wider**, not narrower — the far edge swings
nearer and wins the perspective divide. Measured on one card at 29°: 198px → 210px.

### The ground has to be a real plane

A backdrop card carries its ground *painted on a wall* far behind the scene, so nothing standing in
front of it parallaxes with it — pan, and the props slide across a ground that never moves. The fix
is a horizontal plane:

```json
{ "src": "/lib/backdrops/grave-grass.png", "w": 1024, "h": 1024,
  "plane": "floor", "order": -2,
  "x": 0, "y": -1.6, "z": -48,
  "size": [130, 92], "repeat": [16, 12] }
```

| Field | Effect |
| --- | --- |
| `plane: "floor"` | Rotate the card −90° about X so it lies flat. `+Y` maps to `−Z`, so the image's **top edge is the far edge** and `scale`/`size[1]` is a **depth**, not a height. |
| `size: [w, d]` | World extent, overriding the `scale` + image-aspect sizing. A tiled floor's world size and its texture aspect are unrelated, so it needs stating outright. |
| `repeat: [u, v]` | Tile the texture (`RepeatWrapping`). Required: near ground wants ~200 px/m, and one stretched image can never supply that at both ends of a 90 m plane. |
| `order` | Paint sequence (`renderOrder`). Backdrop `−3`, ground `−2`, path decal `−1`, everything standing `0`. Transparent sorting is by centroid, which puts far props *behind* a large floor without this. |

Put a prop's base on `floorY` and the ground beneath it is now the same world point — they move
together. Two things that are not optional:

- **Anisotropic filtering.** A floor is viewed at grazing incidence, where plain mipmapping collapses
  it into a smooth smear a few metres out. Every texture gets `anisotropy = getMaxAnisotropy()`.
  (Headless Chromium falls back to SwiftShader, which filters far worse than a real GPU — don't judge
  ground quality from a headless screenshot.)
- **Tone-match the ground to the backdrop**, per channel, or the seam at the floor's far edge reads
  as a bright band. Sample the plate's own near-ground colour and multiply the tile onto it.

An inverse-perspective warp of the backdrop's ground *is* recoverable — plane→image is a homography,
so `-distort Perspective` with four correspondences gives the plan view back — but it is not worth
it: the far rows smear (a few source pixels stretched over hundreds of texture rows) and the near
field lands around 17 px/m where the screen wants 240. Generate an overhead tile instead.

### Depth haze

A scene may carry `meta.fog = {color, density}` (three.js `FogExp2`). Without it a stack of
equally-crisp cards reads as flat no matter how the depths are set — aerial perspective is most of
what says *distance*. Set `color` to the **backdrop's own horizon colour** and the far layers fade
into the plate instead of stopping against it. The backdrop opts out with layer `meta.nofog`, or it
fogs to a flat wash of its own colour. `density: 0.0135` puts ~33% haze at 46 m and ~75% at 86 m.

Status: P0–P5 built and pushed — generate → compose → play works end-to-end. Plan + status:
`notes/diorama-plan.md`. (Was named "Shadowbox"; renamed to Diorama — `/shadowbox` now 404s.)

## Backdrop library

Full-frame background images (the `cut:false` diorama palette entries — props supply `cut:true`).
Flat directory under `Config.backdrops_dir` (`~/.local/share/mj/backdrops/`); one image per backdrop
(no folder). PNG dimensions are read from the IHDR header (no pixel decode).

```
mj backdrop <image.png> [name]        # import a full-frame image into the library
```

Non-PNG input is converted to PNG (the library reads dims from the PNG header). This is how a
[`mj base`](base-and-decorate.md) / [`mj strip`](strip.md) output, or a beach plate, becomes a
selectable diorama backdrop.

## webp

```
mj webp [<prop-name>] [--quality N]     # default quality 82
```

Build-time transcode of library deliverables to `.webp` next to the PNG (the running server just
serves the file — no image-processing dependency at serve time). No name = **every prop + every
backdrop**; a name = just that prop. The diorama `/lib/…` routes **prefer the `.webp`** when present.
WebP keeps the alpha channel, and thanks to [`alpha_bleed`](prop.md) the transparent fringe doesn't
resurrect — the library went ~21M → ~1.5M (~93% smaller). Needs ImageMagick (`magick`/`convert`).

---
Related: [prop](prop.md) · [strip](strip.md) · [base & decorate](base-and-decorate.md) · [world](../world.md)

## The camera box: drift vs walk

`cam: {x, y, z, yaw, pitch}` is a half-extent box in metres plus look limits in degrees. It means
different things in the two modes, which is easy to miss:

- **Drift** (default) uses only `x` and `y`, and clamps them to 1.2 / 0.6 regardless of what the
  scene says. Widening the box does not make the idle parallax swing further.
- **Walk** (`P`) uses the box as hard movement bounds and `yaw`/`pitch` as look limits.

So a scene tuned for a gentle drift — the graveyard started at `1.1 x 0.30 x 1.4`, 20° of yaw —
is not walkable, and opening it up costs the drift nothing. The graveyard now runs
`16 x 1.1 x 26`, 175° yaw, 55° pitch.

Two things to check when you make a scene walkable:

- **Extend the floor behind the origin.** A ground plane that starts a couple of metres in front of
  the camera is fine for drift and runs out from under you the moment you walk backwards. The
  graveyard's floor spans `+30 m` to `−98 m`.
- **There is nothing behind you.** The backdrop is a single card in front; at high `yaw` limits,
  turning round shows the fog colour over ground. Acceptable as haze, but if a scene wants a full
  turn it needs a second plate or a cylinder.

Still missing: collision (you walk through headstones), and the floor is a single flat plane, so
a scene whose ground climbs — as the source graveyard's does — loses its hill.

## Imposters: walking around a flat card

A card cannot be walked around — turn 90 degrees and it is a line. An **imposter** carries a set of
painted bearings instead of one image and shows whichever matches where the viewer is standing:

```json
{ "plane": "imposter", "order": 0,
  "srcs": ["/lib/props/hill-house-000", "…-045", "…-090", … 8 in all],
  "x": 0, "y": 3.42, "z": -22, "scale": 13.96 }
```

Bearing is `atan2(cam.x - L.x, cam.z - L.z)` — 0 straight in front, increasing toward +X — so
`srcs[k]` must be the subject seen from `k * (360/n)` degrees around it. Imposters always face the
viewer; `billboard` is ignored.

**The swap is the hard part.** Changing image while the subject is in plain sight is a visible pop.
So it is *deferred*: each frame the imposter computes the bearing it wants, and only commits when
the subject cannot be seen — either occluded, or off the edge of the screen. The viewer discovers
the new angle after the trees clear, never during.

Occlusion is a real test, not an authored guess: a ray from camera to subject against every layer
flagged `"occluder": true`, sampling the hit UV against a 128px alpha map of that layer's texture.
Hitting a tree card's *quad* proves nothing — most of it is empty — so what counts is whether the
hit lands on an opaque texel.

Two things this needs to work:

- **Occluders on the inside of the circuit.** Trees ringed outside the path look like a forest and
  hide nothing; the swap only ever gets its chance from scenery *between* the walker and the
  subject. The graveyard ring uses 16 inner trees.
- **Normalised frames.** Each bearing is generated independently and lands at its own size and
  height in frame; swap between two of those and the subject jumps, which defeats the point.
  `notes/graveyard/normalize.py` scales every frame to a common content height and pins every
  content bottom to the same row. Width is left alone — a side elevation really is wider.

### What the occlusion test actually requires

Three things, learned the hard way:

**Sample the silhouette, not the centre.** One trunk in front of the middle of a wide house leaves
both flanks in view; swapping then is exactly the pop this mechanism exists to avoid. Six points
are tested across the subject's width and height, and *every* one must be covered.

**Pick occluders by opacity, not by size.** What matters is the fraction of the bounding box that is
actually opaque, because the alpha test correctly sees through everything else:

| prop | opaque | as an occluder |
| --- | --- | --- |
| conifer | 27% | usable in clumps |
| framing tree | 36% | **useless** — a wide box around a thin trunk |
| crypt | 43% | good |
| chapel | 46% | good |
| wagon | 52% | best in the set |

The framing tree measures *higher* than the conifer and hides far less: its opaque pixels are spread
thinly across a wide box, while the conifer's are a solid mass. Read the number, then look at the
art.

**Billboard your occluders.** A card that always faces the viewer always presents its widest
profile — exactly what something whose job is to cover should do. The ring's occluding conifers run
`billboard: 180` (a spruce is near enough rotationally symmetric that full facing is honest); the
wagon runs 30, since it has a definite side. Note this makes `box.updateMatrixWorld(true)` mandatory
before the raycast — the occluders were just re-aimed this frame, and raycasting reads `matrixWorld`.

**Trees are not the only cover.** A solid prop parked *on* the trail hides far more than foliage
five metres off it, because the walker passes within a couple of metres. The wagon at 3 m fills the
frame completely.

**Confine the walker.** This is what makes the rest tractable. Free roaming means the subject can be
viewed from any distance and any angle, so no amount of scenery reliably hides it. `cam.ring =
{x, z, r, w}` pins the walker to a corridor of known radius — then a tree of known size covers a
known angle. The graveyard's corridor is 22 m ± 2.5 m, and at that radius a 10 m house subtends
~26 deg while a clump 6 m away subtends far more.

Measured on the finished scene: a clump on the sightline reports `hidden` with the house still
on-screen; a lone bare trunk in the same spot correctly reports *not* hidden. Sweeping the whole
circuit at 5-degree steps, the house is fully covered for **67% of the ring** across eleven separate
glimpse windows — see or lose it, and it has changed when it comes back.

With `imposterLog` on, `window.__impCam(x, z)` drops the camera anywhere, aims it at the imposter and
reports what the occlusion test makes of that spot. Sweeping that round the circuit measures coverage
far more cheaply and precisely than reading screenshots.

### Turning

**Walk mode has no yaw limit.** Turn as far as you like, either direction, forever. `cam.yaw` was
only ever meant to bound the look-around from a fixed viewpoint, and applying it to a walkthrough
produced a cap no 3D walkthrough has. A scene that genuinely wants one asks with `cam.yawLimit`
(degrees); nothing sets it. Pitch still clamps — to `cam.pitch`, itself capped at 85 degrees, or you
tumble over the top.

If the viewer circles without ever losing sight of the subject, the imposter holds a stale bearing
rather than popping. That is the intended trade. Scene `meta.imposterAlways` swaps on sight and
`meta.imposterLog` narrates, both for debugging; with `imposterLog` on, `window.__imp()` reports
each imposter's shown/wanted bearing and whether it is currently hidden.

## Sky: a dome, not a ring of cards

A wrap-around sky wants `plane: "sky"` — one inside-out sphere, not backdrop cards arranged in a
circle. Cards fail twice over: they are **chords**, so they stop abutting the moment the camera
leaves the centre and gaps open at the joins; and no card is tall enough once the viewer can pitch
up 70 degrees. Both vanish with a sphere.

```json
{ "plane": "sky", "order": -10, "radius": 420,
  "src": "/lib/backdrops/grave-sky.png", "w": 1376, "h": 768,
  "repeat": [4, 1], "horizon": 0.4792, "x": 0, "y": 0, "z": -85 }
```

`repeat[0]` is how many times the plate wraps. The tiling uses **`MirroredRepeatWrapping`** — every
other copy is flipped, so each repeat joins its neighbour edge-to-edge and there is no seam to hide.

Two things the code derives rather than trusting:

- **Vertical repeat.** Wrapping N times covers `360/N` degrees of azimuth with the image's *width*,
  while v still spans a full 180 degrees of latitude. Left at 1, the sky stretches vertically by
  `2N·h/w` — 3.6× at N=4, which turns a painted treeline into a mountain range. It is computed as
  `rx · w / (2h)`, and the band clamps above and below.
- **Horizon placement.** `horizon` (the plate's own painted horizon, as a fraction from the top)
  lands on the sphere's equator via `offset.y = (1 - horizon) - ry/2`. Measure it per plate; do not
  reuse a figure from a different render.

Pull the moon out of the plate into its own billboarded card. Mirrored tiling would flip it, and
repeating the plate would hang one moon in every copy.

**The camera's far plane must clear the dome.** It was 400 m, which silently clipped both a 420 m
sky and the far corners of a large ground plane — the symptom is flat background colour where the
sky should be. Now 6000.
