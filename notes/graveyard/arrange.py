#!/usr/bin/env python3
"""The arrangement: source-image pixel coordinates -> a diorama scene.

Projection lives in scene.py. Columns (cx) are read off a 100px grid laid over the source, so the
screen composition matches; DEPTH and real-world SIZE are named per instance, because the source's
ground climbs a hill while the diorama's floor is flat -- solving depth from the ground contact
returns nonsense within a few dozen pixels of the horizon.

`lift` puts a prop back on that painted hillside. `bb` is the billboard limit in degrees: how far a
card may turn to keep facing the camera. Architecture stays at 0; creatures and roughly-symmetric
plants turn. Five headstone props stand in for the couple of dozen markers in the source.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scene import place, air, frame, FLOOR_Y, LENS, SCENES

PLATE, PLATE_W, PLATE_H = "grave-plate", 1376, 768
PLATE_HORIZON = 0.478          # measured: sky/ground colour crossover row / height
PLATE_D = 110.0                # behind the furthest conifer
PLATE_COVER = 1.32             # oversized so drift never reveals an edge
FOG = {"color": "#2f3854", "density": 0.0135}   # the plate's own horizon colour

# ── standing on the floor: (prop, cx, depth, metres, lift, flip, billboard) ──────────────
# BASE overrides where a prop's ground line sits within its own art (default: the bottom).
STANDING = [
    ("grave-frametree",          340,   9.0,  7.5, 0.00, False,  0),
    ("grave-frametree",         1332,   9.0,  7.5, 0.00,  True,  0),

    ("grave-gate-pier",          310,   6.3,  3.2, 0.00,  True,  0),
    ("grave-gate-pier",         1195,   6.3,  3.2, 0.00, False,  0),

    ("grave-pumpkins",           190,   5.0, 0.42, 0.00, False, 15),
    ("grave-pumpkin-single",    1320,   5.4, 0.38, 0.00,  True, 15),
    ("grave-pumpkin-single",     690,   8.5, 0.34, 0.00, False, 15),
    ("grave-candles",            195,   7.0, 0.45, 0.00, False,  0),
    ("grave-candles",           1440,   7.5, 0.45, 0.00,  True,  0),

    ("grave-grass",              250,   4.6, 0.38, 0.00, False, 30),
    ("grave-grass",              430,   5.2, 0.34, 0.00,  True, 30),
    ("grave-grass",              980,   4.9, 0.36, 0.00, False, 30),
    ("grave-grass",             1500,   5.6, 0.33, 0.00,  True, 30),
    ("grave-grass",              810,   6.4, 0.30, 0.00, False, 30),

    ("grave-headstone-round",     60,   6.0, 0.80, 0.00, False,  0),
    ("grave-headstone-arch",     735,   9.5, 1.05, 0.00, False,  0),
    ("grave-headstone-arch",     972,  11.0, 1.05, 0.00,  True,  0),
    ("grave-headstone-round",    415,  11.5, 0.75, 0.00, False,  0),
    ("grave-headstone-cross",    470,  13.0, 1.80, 0.00,  True,  0),
    ("grave-headstone-cross",    975,  14.0, 1.80, 0.00, False,  0),
    ("grave-headstone-slab",     600,  12.5, 0.90, 0.00,  True,  0),
    ("grave-headstone-obelisk", 1085,  16.0, 2.20, 0.00, False,  0),
    ("grave-headstone-obelisk",  760,  19.0, 2.20, 0.00,  True,  0),
    ("grave-headstone-round",    880,  20.0, 0.75, 0.00,  True,  0),
    ("grave-headstone-arch",    1030,  22.0, 1.05, 0.00, False,  0),

    ("grave-headstone-round",    640,   8.6, 0.70, 0.00,  True,  0),
    ("grave-headstone-arch",     880,  13.5, 0.95, 0.00,  True,  0),
    ("grave-headstone-round",   1130,  18.0, 0.72, 0.00, False,  0),
    ("grave-headstone-cross",    600,  21.0, 1.60, 0.00,  True,  0),
    ("grave-headstone-arch",     460,  17.0, 1.00, 0.00, False,  0),

    ("grave-fence",             1400,  17.0,  1.5, 0.00, False,  0),
    ("grave-fence",              140,  16.0,  1.5, 0.00,  True,  0),

    ("grave-crypt",             1352,  26.0,  3.2, 0.00, False,  0),
    ("grave-crypt",              190,  28.0,  3.0, 0.00,  True,  0),

    ("grave-chapel",             838,  46.0,  8.0, 0.00, False,  0),

    ("grave-conifer",            555,  50.0,  9.5, 0.00, False, 25),
    ("grave-conifer",            470,  58.0, 10.5, 0.00,  True, 25),
    ("grave-conifer",            645,  62.0,  9.0, 0.00, False, 25),
    ("grave-conifer",           1000,  54.0, 10.0, 0.00,  True, 25),
    ("grave-conifer",           1078,  66.0, 11.0, 0.00, False, 25),
    ("grave-conifer",            930,  74.0, 10.0, 0.00,  True, 25),
    ("grave-conifer",            735,  86.0, 11.0, 0.00, False, 25),
]

# ── off the ground: (prop, cx, cy, depth, metres, flip, billboard) ───────────────────────
# The framing trees are deliberately huge and hung off the frame edges: the source shows a
# CORNER of a tree, trunk running off the bottom and branches arching across the top, so the
# card has to be bigger than the view and mostly outside it.
FLOATING = [
    # crows ride the framing trees' branches, clear of the piers that would occlude them
    ("grave-crow",       560,  145,  8.6, 0.46, False, 80),
    ("grave-crow",      1112,  145,  8.6, 0.46,  True, 80),

    ("grave-ghost",      552,  527, 12.5, 0.95, False, 60),   # clear of the left tree's roots
    ("grave-ghost",      735,  430, 18.0, 1.10, False, 60),
    ("grave-ghost",     1010,  445, 16.0, 1.10,  True, 60),
    ("grave-bats",       830,  175, 34.0, 2.10, False, 45),
]

GRASS_W, GRASS_D = 130.0, 92.0     # the floor plane, from 2 m out to 94 m
PATH_W,  PATH_D  =   4.4, 60.0     # 4.4 m plane, path ~2.6 m of it     # the decal laid down its centre
TILE_M = 8.0                       # world size of one grass tile

L = []
fw, fh = frame(PLATE_D)
pscale = fh * PLATE_COVER
L.append({
    "src": f"/lib/backdrops/{PLATE}.png", "w": PLATE_W, "h": PLATE_H,
    "x": 0.0, "y": round(-(0.5 - PLATE_HORIZON) * pscale, 3), "z": -PLATE_D,
    "scale": round(pscale, 3), "horizon": PLATE_HORIZON, "shadow": False,
    "billboard": 0, "flipX": False,
    "order": -3, "meta": {"role": "backdrop", "nofog": True},  # the plate IS the fog colour
})
L.append({
    "src": "/lib/backdrops/grave-grass.png", "w": 1024, "h": 1024,
    "x": 0.0, "y": FLOOR_Y, "z": -(2.0 + GRASS_D / 2), "scale": GRASS_D,
    "size": [GRASS_W, GRASS_D], "repeat": [round(GRASS_W / TILE_M), round(GRASS_D / TILE_M)],
    "plane": "floor", "order": -2, "horizon": 0.5, "shadow": False,
    "billboard": 0, "flipX": False, "meta": {"role": "ground"},
})
L.append({
    "src": "/lib/backdrops/grave-path-decal.png", "w": 1024, "h": 2048,
    "x": 0.0, "y": FLOOR_Y + 0.004, "z": -(2.0 + PATH_D / 2), "scale": PATH_D,
    "size": [PATH_W, PATH_D], "repeat": [1, round(PATH_D / 10.0)],
    "plane": "floor", "order": -1, "horizon": 0.5, "shadow": False,
    "billboard": 0, "flipX": False, "meta": {"role": "path"},
})

BASE = {
    # root flare peaks 12% up the silhouette and resolves to trunk by 20%; soil sits between
    "grave-frametree": 0.15,
}

for p, cx, d, size, lift, flip, bb in STANDING:
    L.append(place(p, cx=cx, d=d, size=size, lift=lift, base=BASE.get(p, 0.0),
                   flip=flip, billboard=bb))
for p, cx, cy, d, size, flip, bb in FLOATING:
    L.append(air(p, cx=cx, cy=cy, d=d, size=size, flip=flip, billboard=bb))

L.sort(key=lambda l: l["z"])

out = {
    "name": "graveyard",
    "meta": {"source": "backdrop.graveyard.spooky.fun.png", "built_by": "gy/arrange.py", "fog": FOG},
    "floorY": FLOOR_Y, "lens": LENS,
    "cam": {"x": 1.1, "y": 0.30, "z": 1.4, "yaw": 20, "pitch": 9},
    "layers": L,
}
os.makedirs(SCENES, exist_ok=True)
path = os.path.join(SCENES, "graveyard.json")
with open(path, "w") as f:
    json.dump(out, f, indent=1)
print(f"{path} — {len(L)} layers, {len({l['src'] for l in L})} distinct images")
