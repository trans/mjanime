#!/usr/bin/env python3
"""Measure where a keyed prop actually meets the ground.

Seating a prop by the bottom of its alpha box assumes the lowest opaque pixel IS the ground
contact. That holds for a headstone and fails for anything with a spreading base -- a root
flare, a drift of grass, a skirt of ivy -- where the art keeps going below the soil line.

Heuristic: walk the opaque width up from the bottom. A prop that meets the ground squarely
reaches most of its base width immediately. One with a flare bulges to a peak and then
narrows to the trunk; the soil sits at the peak, where the flare enters the earth.

Reports a suggested `ground_line` (fraction of content height) per prop. It is a suggestion --
eyeball it against the art before committing it to prop.yml.
"""
import os, subprocess, sys

PROPS = os.path.expanduser("~/.local/share/mj/props")
names = sys.argv[1:] or sorted(n for n in os.listdir(PROPS)
                               if os.path.isdir(os.path.join(PROPS, n)))


def profile(path):
    box = subprocess.run(["magick", path, "-alpha", "extract", "-threshold", "1%",
                          "-format", "%@", "info:"], capture_output=True, text=True).stdout.strip()
    wh, xy = box.split("+", 1)
    cw, ch = (int(v) for v in wh.split("x"))
    cx, cy = (int(v) for v in xy.split("+"))
    txt = subprocess.run(["magick", path, "-alpha", "extract", "-threshold", "45%",
                          "-crop", f"{cw}x{ch}+{cx}+{cy}", "+repage", "-depth", "8", "txt:-"],
                         capture_output=True, text=True).stdout.splitlines()[1:]
    rows = [0] * ch
    for line in txt:
        head, rest = line.split(":", 1)
        if "#FFFFFF" in rest:
            rows[int(head.split(",")[1])] += 1
    return rows, cw, ch


print(f"{'prop':<26}{'first':>7}{'peak':>8}{'settled':>9}{'flare':>7}   ground_line")
for n in names:
    p = os.path.join(PROPS, n, "prop.png")
    if not os.path.exists(p):
        continue
    rows, cw, ch = profile(p)
    up = rows[::-1]                                   # index 0 = content bottom
    band = up[:int(ch * 0.35)]                        # only the base matters
    if not band or max(band) == 0:
        continue
    peak = max(band)
    peak_i = band.index(peak)
    # width it settles to just above the flare
    tail = up[int(ch * 0.22):int(ch * 0.40)]
    settled = sorted(tail)[len(tail) // 2] if tail else peak
    flare = peak / settled if settled else 1.0
    # A wide PLINTH (obelisk step, fence kerb, candle ledge) also bulges past the settled
    # width, but it is already wide at the very first opaque row -- and it genuinely sits ON
    # the ground. A FLARE starts narrow (root tips, bough ends) and swells. That first row is
    # what separates them.
    # not the literal first row -- that is a handful of antialiased pixels on almost any prop.
    # Sample a band just above it, where a plinth is already at full width.
    lo, hi = int(ch * 0.03), int(ch * 0.06)
    band0 = [w for w in up[lo:hi]] or [0]
    first = sorted(band0)[len(band0) // 2]
    plinth = first >= 0.55 * peak
    gl = 0.0 if (plinth or flare <= 1.6) else round(peak_i / ch, 3)
    why = "plinth, sits on ground" if plinth else ("flared base" if gl else "flat base")
    print(f"{n:<26}{first:>7}{peak:>8}{settled:>9}{flare:>7.2f}   {gl:>6.3f}  {why}")
