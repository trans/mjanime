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
