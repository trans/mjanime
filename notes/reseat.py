#!/usr/bin/env python3
"""Recolour the green stadium seat to another hue, without regenerating it.

The seat art is 768x1443, which is not a size Nano can produce, so a regeneration could never
register against the original -- and registration is the whole point, since the spectator sprites
are drawn to sit in this exact seat. A hue rotation keeps every pixel where it is.

Only the green plastic is touched. The grey frame and the dark shadows are left alone by selecting
on hue and saturation, so the seat changes colour while its hardware does not. The rotation is a
fixed offset rather than a flattening onto one hue, which preserves the plastic's own variation.
"""
import numpy as np
from PIL import Image

GREEN = (90, 175)


def _hsv(rgb):
    mx = rgb.max(2); mn = rgb.min(2); d = mx - mn
    v = mx
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    i = d > 1e-6
    hh = np.zeros_like(mx)
    sel = i & (mx == r); hh[sel] = ((g - b) / np.maximum(d, 1e-6))[sel] % 6
    sel = i & (mx == g) & (mx != r); hh[sel] = (((b - r) / np.maximum(d, 1e-6)) + 2)[sel]
    sel = i & (mx == b) & (mx != r) & (mx != g); hh[sel] = (((r - g) / np.maximum(d, 1e-6)) + 4)[sel]
    return (hh * 60) % 360, s, v


def _rgb(h, s, v):
    h = h % 360
    c = v * s
    x = c * (1 - np.abs((h / 60) % 2 - 1))
    m = v - c
    z = np.zeros_like(h)
    # select() needs the conditions broadcast to the stacked shape, so choose per channel
    cond = [h < 60, h < 120, h < 180, h < 240, h < 300, h >= 300]
    r = np.select(cond, [c, x, z, z, x, c])
    g = np.select(cond, [x, c, c, x, z, z])
    b = np.select(cond, [z, z, x, c, c, x])
    return np.stack([r, g, b], -1) + m[..., None]


def recolour(path, target_hue, sat_scale=1.0, s_min=0.12):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.float64)
    rgb = a[..., :3] / 255.0
    h, s, v = _hsv(rgb)
    mask = (h >= GREEN[0]) & (h < GREEN[1]) & (s > s_min) & (a[..., 3] > 0)
    centre = np.median(h[mask])
    delta = (target_hue - centre) % 360
    h2 = np.where(mask, (h + delta) % 360, h)
    s2 = np.where(mask, np.clip(s * sat_scale, 0, 1), s)
    out = _rgb(h2, s2, v) * 255.0
    res = np.dstack([np.clip(out, 0, 255), a[..., 3]]).astype(np.uint8)
    return Image.fromarray(res, "RGBA"), centre, float(mask.mean())
