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
