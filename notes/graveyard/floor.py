#!/usr/bin/env python3
"""Recover a top-down GROUND texture from the backdrop plate.

The plate is a perspective view of (roughly) a flat ground plane, and plane->image is a
homography -- so the inverse homography gives the plan view straight back. Warp the plate's
lower half into a top-down map, lay that on a horizontal plane at floorY, and a headstone at
(x, z) and the ground texel at (x, z) are the SAME world point: they parallax together.

Screen->world for a ground plane `EYE` below a camera at the origin looking down -z:
    y_n = -EYE / (d * tan_v)   ->   d = EYE / (-y_n * tan_v)
    x_n = X / (tan_h * d)      ->   X = x_n * tan_h * d

The plate only ever painted the trapezoid its own camera could see, so the near corners of the
output fall outside it. Those get a tiled grass wash underneath -- the path, which is what the
eye actually tracks, comes from the real warp.
"""
import math, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
PLATE = os.path.join(HERE, "backdrop", "decorated.png")
OUT = os.path.join(HERE, "grave-floor.png")

PW, PH = 1376, 768
P_HORIZON = 0.478 * PH          # measured sky/ground crossover row
LENS, ASPECT, EYE = 62.0, 16 / 9, 1.6
TAN_H = math.tan(math.radians(LENS) / 2)
TAN_V = TAN_H / ASPECT

DN, DF = 4.545, 55.0            # near/far depth covered by the floor plane
XM = 33.0                       # half-width; == the frame half-width at DF
PPM = 31.03                     # texels per metre (isotropic)
TW = round(2 * XM * PPM)
TH = round((DF - DN) * PPM)


def src_px(X, d):
    """World ground point -> plate pixel."""
    y_n = -EYE / (d * TAN_V)
    x_n = X / (TAN_H * d)
    return PW / 2 + x_n * PW / 2, P_HORIZON - y_n * PH / 2


def dst_px(X, d):
    """World ground point -> texel in the top-down map (v=0 is the FAR edge)."""
    return (X + XM) / (2 * XM) * TW, (DF - d) / (DF - DN) * TH


# Four correspondences = the homography. Use the plate's own ground trapezoid, so every control
# point sits inside the source and the solve stays well conditioned.
d_far, d_near = DF, DN
X_far = TAN_H * d_far           # world half-width the plate spans at each depth
X_near = TAN_H * d_near
pairs = []
for X, d in ((-X_far, d_far), (X_far, d_far), (X_near, d_near), (-X_near, d_near)):
    sx, sy = src_px(X, d)
    dx, dy = dst_px(X, d)
    pairs += [f"{sx:.2f},{sy:.2f}", f"{dx:.2f},{dy:.2f}"]

print(f"texture {TW}x{TH}  ({2*XM:.0f}m x {DF-DN:.1f}m @ {PPM:.1f} px/m)")
for i in range(0, len(pairs), 2):
    print(f"  plate {pairs[i]:>18}  ->  floor {pairs[i+1]}")

# 1. grass wash: a patch of the plate's near grass, scaled to roughly the right blade size,
#    mirror-tiled across the whole plane so the corners the plate never saw are not holes.
subprocess.run(["magick", PLATE, "-crop", "520x150+90+610", "+repage", "-resize", "45%",
                "(", "+clone", "-flop", ")", "+append",
                "(", "+clone", "-flip", ")", "-append",
                "-blur", "0x1.2", "-write", "mpr:tile", "+delete",
                "-size", f"{TW}x{TH}", "tile:mpr:tile",
                "-modulate", "100,85,100", os.path.join(HERE, "_grass.png")], check=True)

# 2. the real warp
subprocess.run(["magick", PLATE,
                "-virtual-pixel", "transparent", "-alpha", "set",
                "-set", "option:distort:viewport", f"{TW}x{TH}+0+0",
                "-distort", "Perspective", " ".join(pairs), "+repage",
                os.path.join(HERE, "_warp.png")], check=True)

# 3. wash under warp, then fade the FAR edge out so the plane dissolves into the plate
#    instead of ending on a hard line at 55 m.
subprocess.run(["magick", os.path.join(HERE, "_grass.png"), os.path.join(HERE, "_warp.png"),
                "-composite",
                "(", "-size", f"{TW}x{TH}", "gradient:black-white",
                "-function", "polynomial", "-1.9,2.9,0",  # hold ~1 over the near 4/5, fall to 0 far
                ")", "-alpha", "off", "-compose", "copy_opacity", "-composite",
                OUT], check=True)
print("wrote", OUT, subprocess.run(["identify", "-format", "%wx%h", OUT],
                                   capture_output=True, text=True).stdout)
