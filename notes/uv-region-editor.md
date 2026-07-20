# The UV Region Editor (a small, reusable idea)

A tiny in-canvas tool for **defining a region on an image by hand** — a box, an
ellipse, a mask — and getting back **numbers you can paste into code**. It grew
out of two needs in the Fun House (mapping a ship's hit zones; masking a
parrot's beak) and turned out to be the same tool both times.

## The core idea: everything in normalized UV

Never store pixels. Store **fractions of the image** — `u,v` in `[0,1]` for a
point, `w,h` (or `rx,ry`) for a size. A box is `{u, v, w, h}`; an ellipse is
`{u, v, rx, ry}`.

Why: the same numbers work at **any** canvas/screen size, on the original render
*or* a downscaled copy, in the editor *and* in the game. The value you read in
the tool drops straight into the renderer with zero conversion.

The only conversion happens at the edges, through the **same cover-fit transform
you draw the image with**:

```
cover = max(W/IW, H/IH)          // fill the viewport, crop the overflow
dw = IW*cover, dh = IH*cover     // drawn image size
ox = (W-dw)/2,  oy = (H-dh)/2    // top-left of the drawn image

screen → uv:  u = (mx-ox)/dw,        v = (my-oy)/dh
uv → screen:  x = ox + u*dw,         y = oy + v*dh
```

Use that one pair of formulas for the mouse, for drawing the handle, and for the
renderer. Everything stays consistent.

## Interactions that feel good

- **The readout IS the deliverable.** Draw the live `u,v,rx,ry` on screen at all
  times. You never guess a number — you nudge until it looks right and read it
  off. (Then paste it into code, or add a "copy JSON" button.)
- **Drag = move, wheel = resize.** Dragging sets the center to the cursor;
  wheel scales the radius/size. Hold **Shift** to resize one axis only (height),
  **Alt** for the other (width) — so you can match a non-round shape.
- **Arrow keys = fine nudge**, plus a couple of keys for each size axis, for
  pixel-perfect finishing after the coarse drag.
- **A visible outline** (dashed) so the region is obvious while you tune it.
- Gate it behind a key (here: `e`) so it's dev-only and never in a player's way.

## Two shapes, one tool

- **Rectangles** → hit zones. In `ship-map.html` you draw/label boxes over the
  ship (hull, deck, sails, flag, …) and export `[{part,u,v,w,h}, …]`. The game
  does a point-in-box test in the same UV space.
- **Ellipse** → a soft-ish mask. In `treasure.html` one ellipse marks the
  parrot's beak; the renderer clips to it and only animates *inside* it.

## The extension: per-frame alignment offset

When you animate by **swapping whole frames** (e.g. three separate AI renders of
the same room with the beak progressively open), the frames don't line up — the
*entire* image drifts a few pixels between renders, so a crossfade shimmers.

Two-part fix, both in UV:

1. **Lock everything to one base frame** and only draw the other frames *inside
   the region mask*. Outside the mask the picture is literally the same image
   every tick, so it can't drift.
2. **Give each frame a small `(dx, dy)` offset** and draw it at
   `(ox + (u+dx)*dw, oy + (v+dy)*dh)`. The editor lets you *hold* one frame and
   slide it until its head/anchor sits exactly on the base frame. Now only the
   thing that's supposed to move (the beak) actually moves.

`dx,dy` are normalized too, so they're baked as constants and Just Work.

The proper endgame is a **transparent cutout** of only the moving part (one PNG
with alpha, composited over a static base) — no mask, no offsets. The region +
offset editor is the good-enough-now version, and a fast way to *find* where the
cutout should sit.

## Porting to a web UI

It's a self-contained component: a `<canvas>`, the cover-fit transform, a list
of regions (each `{type, u, v, w/rx, h/ry, …meta}`), pointer/wheel handlers, a
live readout, and JSON in/out. Natural extensions:

- **Shapes:** rect, ellipse, and polygon (click to drop points) — all still
  normalized.
- **Feathered masks:** give a region a `feather` fraction and render it through
  a radial/linear alpha gradient instead of a hard clip, to kill the seam.
- **Per-layer offset:** the `(dx,dy)` alignment trick generalizes to any
  layer/frame you're compositing.
- **Export:** the readout, but as copyable JSON — that's the whole point.

Good fits: masking a relight region, defining a prop cutout box, or marking an
alignment anchor between two generations of the same image.
