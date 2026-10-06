#!/usr/bin/env python3
"""Split 'seat with litter on it' into a reusable item layer and a shadow layer.

The two seat renders are pixel registered, so their difference is exactly the litter plus the
shadow it casts. Those two must not be extracted together: an item is OPAQUE and carries its own
colour, while a shadow is a MULTIPLY on whatever lies beneath it. Bake the shadow into an opaque
layer and it arrives on a red seat still tinted blue.

They separate on how the channels move. A shadow scales R, G and B by nearly the same factor --
it darkens without changing hue. An item replaces the colour outright, so the three ratios diverge.
So classify on the SPREAD of the per-channel ratio, not on brightness.

Returns (items RGBA, shadow multiply map) so any seat can be recomposed as

    out = seat * shadow          # darken
    out = over(items, out)       # then paste the litter
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

EPS = 1e-6


def _hsv(rgb):
    mx = rgb.max(2); mn = rgb.min(2); d = mx - mn
    v = mx
    sat = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hh = np.zeros_like(mx); i = d > 1e-6
    sel = i & (mx == r); hh[sel] = ((g - b) / np.maximum(d, 1e-6))[sel] % 6
    sel = i & (mx == g) & (mx != r); hh[sel] = (((b - r) / np.maximum(d, 1e-6)) + 2)[sel]
    sel = i & (mx == b) & (mx != r) & (mx != g); hh[sel] = (((r - g) / np.maximum(d, 1e-6)) + 4)[sel]
    return (hh * 60) % 360, sat, v


def _despeckle(mask, min_px):
    """Drop isolated blobs, keep thin parts that hang off a big one.

    An erode/dilate opening was the obvious tool and is the wrong one: it eats the straw and the
    loose popcorn along with the noise, and the holes it leaves cost more than the speckle did.
    Labelling connected components and dropping the small ones keeps anything attached to the cup
    or the box however thin it gets.
    """
    if min_px <= 0:
        return mask
    lab, n = ndimage.label(mask)
    if n == 0:
        return mask
    keep = np.zeros(n + 1, bool)
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    keep[1:] = sizes >= min_px
    return keep[lab]


def split(empty_p, saved_p, spread_thr=0.13, diff_thr=14.0, feather=1.0, min_px=100,
          seat_band=None):
    E = np.asarray(Image.open(empty_p).convert("RGBA")).astype(np.float64)
    S = np.asarray(Image.open(saved_p).convert("RGBA")).astype(np.float64)
    e, s = E[..., :3], S[..., :3]
    alpha = S[..., 3]

    diff = np.abs(s - e).sum(2)
    r = s / np.maximum(e, 8.0)                      # floor avoids wild ratios in near-black pixels
    spread = r.max(2) - r.min(2)
    rmean = r.mean(2)

    changed = diff > diff_thr
    is_item = changed & (spread >= spread_thr)
    is_shadow = changed & (spread < spread_thr) & (rmean < 1.0)

    # The "saved" seat was generated, not copied, so the model redrew the seat itself a little.
    # That re-rendering noise scatters single pixels into the item class, and each one carries the
    # SOURCE seat colour onto whatever seat it is later composited over -- blue freckles on a red
    # chair. An opening (erode then dilate) removes anything thinner than the structuring element
    # while leaving the cup, box and glasses untouched, because they are large solid shapes.
    # A pixel still wearing the SEAT's own hue cannot be litter -- none of the objects share it.
    # Those are softly shadowed seat that the ratio test misread, and left in the item layer they
    # arrive as a blue smudge on every other colour of chair. Send them to the shadow class.
    if seat_band is not None:
        sh_, ss_, _ = _hsv(s / 255.0)
        seat_hue = (sh_ >= seat_band[0]) & (sh_ < seat_band[1]) & (ss_ > 0.10)
        is_shadow = is_shadow | (is_item & seat_hue)
        is_item = is_item & ~seat_hue

    is_item = ndimage.binary_fill_holes(_despeckle(is_item, min_px))
    is_shadow = _despeckle(is_shadow, min_px) & ~is_item

    # Item alpha: hard inside, softened by a pixel so the cut edge is not aliased.
    ia = Image.fromarray((is_item * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(feather))
    ia = np.asarray(ia).astype(np.float64) / 255.0
    ia *= (alpha > 128)

    items = np.dstack([s, ia * 255.0]).astype(np.uint8)

    # Shadow map: 1.0 = untouched, <1 darkens. Only where we judged shadow.
    shadow = np.where(is_shadow, np.clip(rmean, 0.25, 1.0), 1.0)
    shadow = np.asarray(Image.fromarray((shadow * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(feather))).astype(np.float64) / 255.0

    return Image.fromarray(items, "RGBA"), shadow, dict(
        item_px=int(is_item.sum()), shadow_px=int(is_shadow.sum()),
        min_shadow=float(shadow.min()))


def compose(seat_p, items, shadow):
    base = Image.open(seat_p).convert("RGBA")
    a = np.asarray(base).astype(np.float64)
    a[..., :3] *= shadow[..., None]
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    out.alpha_composite(items)
    return out
