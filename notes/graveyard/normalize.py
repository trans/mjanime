#!/usr/bin/env python3
"""Normalise a set of imposter bearings so swapping between them is invisible.

Each bearing was generated independently, so each lands at its own size and sits at its own height
inside the 1024 frame. Swap between two of those and the house jumps -- which defeats the whole
point of hiding the swap behind an occluder.

A building's HEIGHT does not change as you walk around it, and neither does the ground it stands
on. So: scale every frame until its content height matches, drop every content bottom onto the same
row, and centre it horizontally. Width is left alone -- a side elevation really is wider than a
front one. After this the whole set shares one scale and one ground line.
"""
import os, subprocess, sys

PROPS = os.path.expanduser("~/.local/share/mj/props")
SRC = sys.argv[1] if len(sys.argv) > 1 else "house"
DST = sys.argv[2] if len(sys.argv) > 2 else "hill-house"
ANGLES = ["000", "045", "090", "135", "180", "225", "270", "315"]
FRAME = 1024
TARGET_H = 880          # content height every bearing is scaled to
BASE_ROW = 986          # row the content bottom lands on, in every frame


def box(path):
    b = subprocess.run(["magick", path, "-alpha", "extract", "-threshold", "1%",
                        "-format", "%@", "info:"], capture_output=True, text=True).stdout.strip()
    wh, xy = b.split("+", 1)
    w, h = (int(v) for v in wh.split("x"))
    x, y = (int(v) for v in xy.split("+"))
    return x, y, w, h


print(f"{'bearing':<10}{'content in':>14}{'scale':>8}{'content out':>15}")
for a in ANGLES:
    src = os.path.join(PROPS, f"{SRC}-{a}", "prop.png")
    d = os.path.join(PROPS, f"{DST}-{a}")
    os.makedirs(d, exist_ok=True)
    x, y, w, h = box(src)
    k = TARGET_H / h
    nw, nh = round(w * k), round(h * k)
    # crop to content, rescale, then repaste with the bottom pinned to BASE_ROW
    subprocess.run(["magick", src, "-crop", f"{w}x{h}+{x}+{y}", "+repage",
                    "-resize", f"{nw}x{nh}!",
                    "-background", "none", "-gravity", "north",
                    "-extent", f"{nw}x{BASE_ROW}",
                    "-gravity", "center", "-extent", f"{FRAME}x{BASE_ROW}",
                    "-gravity", "north", "-extent", f"{FRAME}x{FRAME}",
                    os.path.join(d, "prop.png")], check=True)
    ox, oy, ow, oh = box(os.path.join(d, "prop.png"))
    print(f"{DST}-{a:<4}{w:>7}x{h:<6}{k:>8.3f}{ow:>8}x{oh:<6} bottom row {oy+oh}")
