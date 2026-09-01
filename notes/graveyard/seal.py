#!/usr/bin/env python3
"""Seal interior holes in a keyed prop.

A distance-from-background key is purely per-pixel, so when the SUBJECT contains the background
colour it gets punched through. The gate pier's shadowed stone measures 0-20 against a pure-black
backdrop -- no threshold separates those, because there is nothing to separate: they are the same
colour. The missing information is spatial, not chromatic.

So: take a permissive mask, close it to bridge thin dark seams, flood-fill the background in from
the borders, and force everything NOT reachable from outside to full alpha. The outer few pixels
keep the original soft ramp, so the cut edge stays feathered.

    seal.py <prop-dir> [--thresh 1] [--close 10] [--keep-edge 3]
"""
import os, subprocess, sys

d = sys.argv[1]
opt = dict(zip(sys.argv[2::2], sys.argv[3::2]))
THRESH = opt.get("--thresh", "1")     # % — anything above this is "not background"
CLOSE = opt.get("--close", "10")      # px — bridges dark seams that split the silhouette
KEEP = opt.get("--keep-edge", "3")    # px of original soft alpha preserved at the boundary

render = os.path.join(d, "render.png")
prop = os.path.join(d, "prop.png")
tmp = lambda n: os.path.join(d, f"_seal_{n}.png")

# 1. permissive silhouette, closed so a thin black seam doesn't cut the shape in two
subprocess.run(["magick", render, "-alpha", "off", "-colorspace", "gray",
                "-threshold", f"{THRESH}%", "-morphology", "Close", f"Disk:{CLOSE}",
                tmp("closed")], check=True)

# 2. flood the background in from every border, then invert: what is left is interior holes
subprocess.run(["magick", tmp("closed"), "-bordercolor", "black", "-border", "1",
                "-fill", "white", "-floodfill", "+0+0", "black",
                "-shave", "1x1", "-negate", tmp("holes")], check=True)

# 3. full silhouette = closed mask OR its holes, eroded so the feathered rim survives
subprocess.run(["magick", tmp("closed"), tmp("holes"), "-compose", "lighten", "-composite",
                "-morphology", "Erode", f"Disk:{KEEP}", tmp("solid")], check=True)

# 4. new alpha = max(original soft alpha, sealed interior)
subprocess.run(["magick", prop, "-alpha", "extract", tmp("solid"),
                "-compose", "lighten", "-composite", tmp("alpha")], check=True)
subprocess.run(["magick", prop, tmp("alpha"), "-alpha", "off",
                "-compose", "copy_opacity", "-composite", prop], check=True)

before = subprocess.run(["magick", tmp("closed"), "-format", "%[fx:mean]", "info:"],
                        capture_output=True, text=True).stdout
after = subprocess.run(["magick", prop, "-alpha", "extract", "-format", "%[fx:mean]", "info:"],
                       capture_output=True, text=True).stdout
print(f"{os.path.basename(d)}: silhouette {float(before)*100:.1f}% of frame, "
      f"alpha coverage now {float(after)*100:.1f}%")
for n in ("closed", "holes", "solid", "alpha"):
    os.remove(tmp(n))
