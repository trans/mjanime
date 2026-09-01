#!/usr/bin/env python3
"""Solve a diorama scene from source-image pixel coordinates.

The source is a real perspective render, so a prop's GROUND CONTACT pixel tells us its depth:
for a ground plane `eye` below the camera, a point touching it at depth d projects to
    y_n = -eye / (d * tan(vfov/2))          (y_n in [-1,1], 0 = horizon)
so                d = eye / (-y_n * tan(vfov/2)).

Everything else follows: at depth d the frame spans H(d) = 2*d*tan(vfov/2) tall and H(d)*aspect
wide, so a pixel position and a pixel height convert straight to world units. Objects ABOVE the
horizon (on the hill, in the sky) can't be solved this way -- they get an explicit depth.

Props carry transparent padding, so the layer `scale` (which sizes the whole IMAGE) is derived
from the trimmed content box: scale = wanted_content_height * img_h / content_h, and the layer
origin is offset so the CONTENT, not the image, lands where we asked.
"""
import json, math, os, subprocess

PROPS = os.path.expanduser("~/.local/share/mj/props")
SCENES = os.path.expanduser("~/.local/share/mj/scenes")
SRC_W, SRC_H = 1672, 941

LENS = 62.0                     # horizontal FOV, degrees -- the scene's `lens`
ASPECT = 16 / 9
EYE = 1.6                       # camera height above the ground plane == -floorY
FLOOR_Y = -EYE

VF = 2 * math.atan(math.tan(math.radians(LENS) / 2) / ASPECT)   # vertical FOV
TAN_V = math.tan(VF / 2)

_geom = {}


def geom(name):
    """(img_w, img_h, content_x, content_y, content_w, content_h) for a prop's keyed cut-out."""
    if name in _geom:
        return _geom[name]
    path = os.path.join(PROPS, name, "prop.png")
    iw, ih = subprocess.run(["magick", path, "-format", "%w %h", "info:"],
                            capture_output=True, text=True, check=True).stdout.split()
    # trim on alpha only; 1% floor drops the faint key residue so the box hugs real content
    box = subprocess.run(["magick", path, "-alpha", "extract", "-threshold", "1%",
                          "-format", "%@", "info:"],
                         capture_output=True, text=True, check=True).stdout.strip()
    wh, xy = box.split("+", 1)
    cw, ch = (int(v) for v in wh.split("x"))
    cx, cy = (int(v) for v in xy.split("+"))
    _geom[name] = (int(iw), int(ih), cx, cy, cw, ch)
    return _geom[name]


def frame(d):
    """World size of the view frustum at depth d."""
    h = 2 * d * TAN_V
    return h * ASPECT, h


def depth_from_base(py):
    """Ground-contact pixel row -> depth. Only valid below the horizon."""
    y_n = 1 - 2 * py / SRC_H
    if y_n >= -1e-4:
        raise ValueError(f"py={py} is at or above the horizon; give an explicit depth")
    return EYE / (-y_n * TAN_V)


def layer(prop, *, cx, base=None, top=None, d=None, cy=None, h_px=None,
          flip=False, billboard=0, shadow=False, src=None, w=None, h=None):
    """Place a prop from source-image pixels.

    cx     -- content centre column in source pixels
    base   -- ground-contact row; solves depth. Use `d` + `cy` for things off the ground.
    top    -- content top row (with `base`, gives the pixel height)
    h_px   -- explicit pixel height when `top` is unhelpful
    """
    if src is None:
        iw, ih, bx, by, bw, bh = geom(prop)
        src = f"/lib/props/{prop}"
    else:
        iw, ih, bx, by, bw, bh = w, h, 0, 0, w, h

    if d is None:
        d = depth_from_base(base)
    fw, fh = frame(d)

    if h_px is None:
        h_px = base - top
    world_h = h_px / SRC_H * fh                      # wanted CONTENT height in world units

    scale = world_h * ih / bh                        # the IMAGE is taller than the content
    lw = scale * iw / ih

    # where the content centre should land
    wx = (cx / SRC_W - 0.5) * fw
    if cy is None:
        cy = base - h_px / 2
    wy = (0.5 - cy / SRC_H) * fh

    # offset the image so the CONTENT lands on (wx, wy)
    cxf = (bx + bw / 2) / iw - 0.5
    cyf = 0.5 - (by + bh / 2) / ih
    if flip:
        cxf = -cxf
    return {
        "src": src, "w": iw, "h": ih,
        "x": round(wx - cxf * lw, 3), "y": round(wy - cyf * scale, 3), "z": round(-d, 3),
        "scale": round(scale, 3), "horizon": 0.5, "shadow": shadow,
        "billboard": billboard, "flipX": flip, "meta": {"prop": prop},
    }


def place(prop, *, cx, d, size, lift=0.0, base=0.0, flip=False, billboard=0, shadow=False):
    """A prop STANDING on the floor: x from the source column, depth and real-world height given.

    The ground-contact solve above is exact only over a flat plane, and the source's graveyard
    climbs a hill -- near the horizon it returns absurd depths (and therefore absurd sizes). For
    anything standing, naming the depth and the metre height keeps relative scale honest, while
    the source column still pins the composition.
    """
    iw, ih, bx, by, bw, bh = geom(prop)
    fw, fh = frame(d)
    scale = size * ih / bh                      # image height that yields `size` of content
    lw = scale * iw / ih
    wx = (cx / SRC_W - 0.5) * fw
    # Seat the prop's GROUND LINE on the floor. That is usually the bottom of the content box,
    # but not always: a tree drawn with a heavy exposed root flare meets the soil part-way up its
    # own silhouette, and seating its lowest root tip on the floor hangs the whole trunk in the
    # air. `base` is the fraction of the content height, measured from the bottom, where the
    # ground actually is -- so the tips below it sink into the earth where they belong.
    wy = FLOOR_Y + lift - base * size + size / 2
    cxf = (bx + bw / 2) / iw - 0.5
    cyf = 0.5 - (by + bh / 2) / ih
    if flip:
        cxf = -cxf
    return {
        "src": f"/lib/props/{prop}", "w": iw, "h": ih,
        "x": round(wx - cxf * lw, 3), "y": round(wy - cyf * scale, 3), "z": round(-d, 3),
        "scale": round(scale, 3), "horizon": 0.5, "shadow": shadow,
        "billboard": billboard, "flipX": flip, "meta": {"prop": prop},
    }


def air(prop, *, cx, cy, d, size, flip=False, billboard=0):
    """A prop OFF the ground (sky, hillside, hovering): both screen axes given in source pixels."""
    iw, ih, bx, by, bw, bh = geom(prop)
    fw, fh = frame(d)
    scale = size * ih / bh
    lw = scale * iw / ih
    wx = (cx / SRC_W - 0.5) * fw
    wy = (0.5 - cy / SRC_H) * fh
    cxf = (bx + bw / 2) / iw - 0.5
    cyf = 0.5 - (by + bh / 2) / ih
    if flip:
        cxf = -cxf
    return {
        "src": f"/lib/props/{prop}", "w": iw, "h": ih,
        "x": round(wx - cxf * lw, 3), "y": round(wy - cyf * scale, 3), "z": round(-d, 3),
        "scale": round(scale, 3), "horizon": 0.5, "shadow": False,
        "billboard": billboard, "flipX": flip, "meta": {"prop": prop},
    }
