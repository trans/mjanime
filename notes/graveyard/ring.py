#!/usr/bin/env python3
"""The circuit: a path that rings a central hill and returns to where it started.

Laid out in POLAR coordinates about the hill rather than by source-image columns -- this scene is
walked, not looked at from one spot. Bearing is measured from +Z toward +X, matching the imposter's
own atan2(dx, dz), so a prop's bearing and the house's chosen bearing agree.

The haunted house on the hill is an IMPOSTER: eight painted bearings, 45 degrees apart, swapped
only while the viewer cannot see it. The occluders that hide it are the inner wood -- trees ringed
INSIDE the path, between the walker and the hill. Trees outside the path would look like a forest
and hide nothing.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scene import place_at, imposter_at, polar, frame, FLOOR_Y, LENS, SCENES

CX, CZ = 0.0, -22.0      # the hill
R = 22.0                 # path radius -- the camera starts at world origin, on the ring at bearing 0
HOUSE_H = 10.0           # must be shorter than the occluding wood, or the roof always shows

HOUSE = [f"hill-house-{a}" for a in ("000", "045", "090", "135", "180", "225", "270", "315")]

L = []

# ── sky enclosure ───────────────────────────────────────────────────────────────────────────────
# One backdrop card is fine while you face forward; the moment yaw opens to a full turn there is
# nothing behind you. Four plates boxed around the hill fix that. Only the plate the walk opens
# facing carries the moon -- repeating it four times would hang four moons in the sky.
SKY_R, SKY_H = 108.0, 156.0
SKY_HORIZON = 0.478
for bearing in (0, 90, 180, 270):
    x, z = polar(CX, CZ, bearing, SKY_R)
    plate = "grave-plate" if bearing == 180 else "grave-sky"
    L.append({
        "src": f"/lib/backdrops/{plate}.png", "w": 1376, "h": 768,
        "x": round(x, 3), "y": round(-(0.5 - SKY_HORIZON) * SKY_H, 3), "z": round(z, 3),
        "scale": SKY_H, "rotY": bearing + 180, "horizon": SKY_HORIZON, "shadow": False,
        "billboard": 0, "flipX": bearing in (90,), "order": -4,
        "meta": {"role": "backdrop", "nofog": True},
    })

# ── ground ──────────────────────────────────────────────────────────────────────────────────────
GRASS_W, GRASS_D, TILE_M = 280.0, 280.0, 8.0
L.append({
    "src": "/lib/backdrops/grave-grass.png", "w": 1024, "h": 1024,
    "x": CX, "y": FLOOR_Y, "z": CZ, "scale": GRASS_D,
    "size": [GRASS_W, GRASS_D], "repeat": [round(GRASS_W / TILE_M), round(GRASS_D / TILE_M)],
    "plane": "floor", "order": -3, "horizon": 0.5, "shadow": False,
    "billboard": 0, "flipX": False, "meta": {"role": "ground"},
})

# ── the path: an octagon of straight decal segments ─────────────────────────────────────────────
# A ring drawn as one big top-down image would be ~17 px/m and mush underfoot. Eight straight
# segments reuse the tiling path decal at full resolution; the corners read as a curve once grass
# grows over the joints. Segment k spans vertices at 45k and 45(k+1), so its midpoint sits at
# 45k+22.5 and its long axis is the tangent there -- which is rotY = bearing - 90.
SEG_LEN = 2 * R * math.sin(math.radians(22.5)) + 2.2      # +overlap so corners do not gap
SEG_R = R * math.cos(math.radians(22.5))
PATH_W = 4.4
for k in range(8):
    bearing = 45 * k + 22.5
    x, z = polar(CX, CZ, bearing, SEG_R)
    L.append({
        "src": "/lib/backdrops/grave-path-decal.png", "w": 1024, "h": 2048,
        "x": round(x, 3), "y": FLOOR_Y + 0.004, "z": round(z, 3), "scale": SEG_LEN,
        "size": [PATH_W, SEG_LEN], "repeat": [1, max(1, round(SEG_LEN / 10.0))],
        "rotY": round(bearing - 90, 2),
        "plane": "floor", "order": -2, "horizon": 0.5, "shadow": False,
        "billboard": 0, "flipX": False, "meta": {"role": "path", "segment": k},
    })

# ── the house on the hill ───────────────────────────────────────────────────────────────────────
L.append(imposter_at(HOUSE, x=CX, z=CZ, size=HOUSE_H, base=0.0, order=0))

# ── the inner wood: these are the OCCLUDERS that hide the swap ──────────────────────────────────
# Spread around the circuit so that wherever you walk, the hill goes behind timber every so often.
# Walker is pinned to r=22 +/- 2.5, so these sit 5.5-7 m away and each subtends ~30 deg -- about
# what the 10 m house subtends at 22 m. Just enough to cover it, with real gaps to glimpse through.
# Taller than the house on purpose: a tree the house out-tops hides nothing.
INNER = [(28, 16.0, 15.5), (58, 15.5, 14.5), (88, 16.5, 16.0), (118, 15.5, 15.0),
         (150, 16.0, 16.5), (180, 15.5, 14.8), (208, 16.5, 15.6), (238, 15.5, 16.2),
         (268, 16.0, 15.0), (298, 15.5, 16.4), (328, 16.5, 14.6),
         (44, 11.5, 9.4), (134, 11.0, 9.8), (222, 11.5, 9.2), (312, 11.0, 9.6)]
for i, (bearing, r, h) in enumerate(INNER):
    x, z = polar(CX, CZ, bearing, r)
    # a clump, not a lone trunk: three abreast so the screen is wider than the house's silhouette
    for j, (db, dr) in enumerate(((-6.5, 0.8), (0.0, 0.0), (6.5, -0.8))):
        cx2, cz2 = polar(CX, CZ, bearing + db, r + dr)
        L.append(place_at("grave-conifer", x=cx2, z=cz2, size=h - abs(db) * 0.12,
                          flip=(j % 2 == 1), occluder=True, billboard=180))
    x2, z2 = polar(CX, CZ, bearing + 3.0, r - 1.6)
    L.append(place_at("grave-frametree", x=x2, z=z2, size=h * 0.62, flip=(i % 2 == 1)))

# ── the outer wood: depth and enclosure, no occlusion duty ──────────────────────────────────────
OUTER = [(b, 28 + (i % 3) * 5, 9.0 + (i % 4) * 0.9) for i, b in enumerate(range(0, 360, 15))]
for i, (bearing, r, h) in enumerate(OUTER):
    x, z = polar(CX, CZ, bearing, r)
    prop = "grave-conifer" if i % 2 else "grave-frametree"
    L.append(place_at(prop, x=x, z=z, size=h, flip=(i % 3 == 0), billboard=20 if i % 2 else 0))

# ── solid occluders parked along the trail ─────────────────────────────────────────────────────
TRAIL = [
    ("grave-wagon",  75, 19.0, 3.6, 30),
    ("grave-wagon", 255, 19.2, 3.6, 30),
    ("grave-crypt",  15, 17.0, 4.2,  0),
    ("grave-crypt", 195, 17.2, 4.0,  0),
    ("grave-crypt", 300, 17.0, 4.4,  0),
]
for prop, bearing, r, size, bb in TRAIL:
    x, z = polar(CX, CZ, bearing, r)
    L.append(place_at(prop, x=x, z=z, size=size, occluder=True, billboard=bb,
                      rotY=(None if bb else bearing + 180)))

# ── the old chapel, demoted to a roadside mausoleum ─────────────────────────────────────────────
x, z = polar(CX, CZ, 205, 33)
L.append(place_at("grave-chapel", x=x, z=z, size=8.0, rotY=205 + 180))

# ── graves, lanterns and clutter along the circuit ──────────────────────────────────────────────
SCATTER = [
    ("grave-headstone-arch",    12, 25.5, 1.05), ("grave-headstone-cross",   30, 26.5, 1.80),
    ("grave-headstone-round",   48, 25.0, 0.75), ("grave-headstone-obelisk", 66, 27.0, 2.20),
    ("grave-headstone-slab",    84, 25.5, 0.95), ("grave-headstone-arch",   102, 26.5, 1.05),
    ("grave-headstone-cross",  126, 25.0, 1.80), ("grave-headstone-round",  148, 26.5, 0.75),
    ("grave-headstone-obelisk",170, 25.5, 2.20), ("grave-headstone-arch",   192, 27.0, 1.05),
    ("grave-headstone-slab",   228, 25.5, 0.95), ("grave-headstone-round",  248, 26.5, 0.75),
    ("grave-headstone-cross",  268, 25.0, 1.80), ("grave-headstone-arch",   300, 26.5, 1.05),
    ("grave-headstone-obelisk",320, 25.5, 2.20), ("grave-headstone-slab",   342, 26.5, 0.95),
    ("grave-headstone-arch",    22, 18.0, 1.05), ("grave-headstone-round",   75, 18.5, 0.75),
    ("grave-headstone-cross",  160, 18.0, 1.80), ("grave-headstone-slab",   240, 18.5, 0.95),
    ("grave-headstone-round",  310, 18.0, 0.75),
    ("grave-crypt",             68, 31.0, 3.2),  ("grave-crypt",            288, 31.0, 3.0),
]
for i, (prop, bearing, r, size) in enumerate(SCATTER):
    x, z = polar(CX, CZ, bearing, r)
    L.append(place_at(prop, x=x, z=z, size=size, flip=(i % 2 == 0),
                      rotY=(bearing + 180 + (17 if i % 3 else -13))))

# gate piers flanking the start of the circuit, facing each other across the path
for side, flip in ((-1, True), (1, False)):
    L.append(place_at("grave-gate-pier", x=side * 3.4, z=1.0, size=3.2, flip=flip))

CLUTTER = [
    ("grave-pumpkins",         6, 20.0, 0.42, 15), ("grave-pumpkin-single", 350, 20.4, 0.38, 15),
    ("grave-pumpkin-single", 150, 20.2, 0.38, 15), ("grave-pumpkins",       210, 20.6, 0.42, 15),
    ("grave-candles",         44, 20.6, 0.45,  0), ("grave-candles",        188, 20.2, 0.45,  0),
    ("grave-candles",        278, 20.5, 0.45,  0),
]
for prop, bearing, r, size, bb in CLUTTER:
    x, z = polar(CX, CZ, bearing, r)
    L.append(place_at(prop, x=x, z=z, size=size, billboard=bb))

for i in range(24):                                   # weeds along the verges
    bearing = i * 15 + 7
    for r in (R - 3.0, R + 3.0):
        x, z = polar(CX, CZ, bearing, r)
        L.append(place_at("grave-grass", x=x, z=z, size=0.34, flip=(i % 2 == 0), billboard=30))

GHOSTS = [(30, 17.0, 1.1, 2.4), (150, 17.5, 1.1, 2.0), (265, 17.0, 1.1, 2.6)]
for bearing, r, size, hover in GHOSTS:
    x, z = polar(CX, CZ, bearing, r)
    lay = place_at("grave-ghost", x=x, z=z, size=size, billboard=60)
    lay["y"] = round(lay["y"] + hover, 3)
    L.append(lay)

L.sort(key=lambda l: l["z"])

out = {
    "name": "graveyard-ring",
    "meta": {"source": "backdrop.graveyard.spooky.fun.png", "built_by": "gy/ring.py",
             "fog": {"color": "#2f3854", "density": 0.0115}},
    "floorY": FLOOR_Y, "lens": LENS,
    # a full circuit needs a full turn; the box has to contain the whole ring, not a drift pocket
    "cam": {"x": 30.0, "y": 1.1, "z": 50.0, "yaw": 999, "pitch": 55,
            # yaw >= 360 = spin freely, forever. `ring` pins the walker to the path corridor,
            # which is what makes a tree of known size reliably cover the hill.
            "ring": {"x": CX, "z": CZ, "r": R, "w": 5.0}},
    "layers": L,
}
os.makedirs(SCENES, exist_ok=True)
path = os.path.join(SCENES, "graveyard-ring.json")
with open(path, "w") as f:
    json.dump(out, f, indent=1)
occ = sum(1 for l in L if l.get("occluder"))
print(f"{path} — {len(L)} layers, {occ} occluders, path radius {R} m")
