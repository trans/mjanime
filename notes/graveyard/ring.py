#!/usr/bin/env python3
"""The circuit: a long path ringing a hill, with the haunted house on the summit.

Scale is the whole design here. The first attempt put the house 22 m away, where it subtended 26
degrees and needed a wall of conifers to cover -- which is why you could barely see it. Pushed out
to 85 m and up onto a hill, it subtends 7 degrees, and a SINGLE tree beside the path covers it
completely. Distance buys back the sparseness: ten occluders instead of thirty-three, and a house
that reads as a landmark on a hill rather than a facade in your face.

Laid out in polar coordinates about the hill; bearing runs from +Z toward +X, matching the
imposter's own atan2(dx, dz).
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scene import place_at, imposter_at, polar, frame, FLOOR_Y, LENS, SCENES

R = 85.0                 # path radius. Camera starts at the world origin, on the ring at bearing 0.
CX, CZ = 0.0, -R         # the hill
CORRIDOR = 7.0           # how far you may stray off the path, total
HILL_H = 15.0            # -> 34 m across
HOUSE_H = 11.0           # on the summit
SUMMIT = 0.90            # fraction up the hill where the ground flattens off

HOUSE = [f"hill-house-{a}" for a in ("000", "045", "090", "135", "180", "225", "270", "315")]

L = []

# ── sky: one inside-out dome, the plate mirror-tiled around it ──────────────────────────────────
# Cards in a ring do not work: they are chords, so they stop abutting as soon as the camera leaves
# the centre, and no card is tall enough once you can pitch up 70 degrees. A dome has neither
# problem, and MirroredRepeatWrapping does the flip-flop tiling in the texture unit.
SKY_R, SKY_REPEAT, SKY_HORIZON = 420.0, 4, 0.4792   # measured on grave-sky, not the original plate
L.append({
    "src": "/lib/backdrops/grave-sky.png", "w": 1376, "h": 768,
    "x": CX, "y": 0.0, "z": CZ, "scale": SKY_R, "radius": SKY_R,
    "repeat": [SKY_REPEAT, 1], "horizon": SKY_HORIZON,
    "plane": "sky", "order": -10, "shadow": False, "billboard": 0, "flipX": False,
    "meta": {"role": "backdrop", "nofog": True},
})
MOON_B, MOON_R, MOON_D = 180.0, 250.0, 21.0
mx, mz = polar(CX, CZ, MOON_B, MOON_R)
L.append({
    "src": "/lib/backdrops/grave-moon.png", "w": 160, "h": 160,
    "x": round(mx, 3), "y": round(MOON_R * math.tan(math.radians(14.2)), 3), "z": round(mz, 3),
    "scale": MOON_D, "horizon": 0.5, "shadow": False,
    "billboard": 180, "flipX": False, "order": -9,
    "meta": {"role": "moon", "nofog": True},
})

# ── ground ──────────────────────────────────────────────────────────────────────────────────────
GRASS, TILE_M = 520.0, 8.0
L.append({
    "src": "/lib/backdrops/grave-grass.png", "w": 1024, "h": 1024,
    "x": CX, "y": FLOOR_Y, "z": CZ, "scale": GRASS,
    "size": [GRASS, GRASS], "repeat": [round(GRASS / TILE_M)] * 2,
    "plane": "floor", "order": -3, "horizon": 0.5, "shadow": False,
    "billboard": 0, "flipX": False, "meta": {"role": "ground"},
})

# ── the path: 16 segments, so the ring reads as a curve rather than an octagon ──────────────────
SEGS = 16
HALF = 180.0 / SEGS
SEG_LEN = 2 * R * math.sin(math.radians(HALF)) + 2.0
SEG_R = R * math.cos(math.radians(HALF))
for k in range(SEGS):
    bearing = (360.0 / SEGS) * k + HALF
    x, z = polar(CX, CZ, bearing, SEG_R)
    L.append({
        "src": "/lib/backdrops/grave-path-decal.png", "w": 1024, "h": 2048,
        "x": round(x, 3), "y": FLOOR_Y + 0.004, "z": round(z, 3), "scale": SEG_LEN,
        "size": [4.6, SEG_LEN], "repeat": [1, max(1, round(SEG_LEN / 10.0))],
        "rotY": round(bearing - 90, 2),
        "plane": "floor", "order": -2, "horizon": 0.5, "shadow": False,
        "billboard": 0, "flipX": False, "meta": {"role": "path", "segment": k},
    })

# ── the hill, and the house on its summit ───────────────────────────────────────────────────────
L.append(place_at("grave-hill", x=CX, z=CZ, size=HILL_H, billboard=180, order=-1))
house = imposter_at(HOUSE, x=CX, z=CZ, size=HOUSE_H, base=0.0, order=0)
house["y"] = round(house["y"] + HILL_H * SUMMIT, 3)
L.append(house)

# ── occluders: sparse CLUMPS, not a wall ────────────────────────────────────────────────────────
# One tree hides the house for a window of only asin(half_width / radius) ~ 3 deg of travel,
# however close it stands -- the ratio, not the distance, sets it. Widening the window needs a
# wider screen, so occluders come in threes spanning ~20 m: asin(10/77) ~ 7.5 deg either side.
# Ten clumps around a 534 m circuit leaves the house in plain view for most of the walk, which is
# the point -- the first attempt fenced it off entirely.
OCC = [(38, 16.5), (72, 15.0), (108, 17.0), (140, 15.5), (172, 16.0),
       (205, 17.0), (238, 15.0), (272, 16.5), (305, 15.5), (338, 16.0)]
for i, (bearing, h) in enumerate(OCC):
    for j, db in enumerate((-5.2, 0.0, 5.2)):
        x, z = polar(CX, CZ, bearing + db, R - 8.0 + (j - 1) * 1.5)
        L.append(place_at("grave-conifer", x=x, z=z, size=h - abs(db) * 0.15,
                          flip=(j % 2 == 1), occluder=True, billboard=180))

# ── solid cover parked on the trail ─────────────────────────────────────────────────────────────
TRAIL = [("grave-wagon", 55, 3.6, 30), ("grave-wagon", 228, 3.6, 30),
         ("grave-crypt", 128, 4.2, 0), ("grave-crypt", 292, 4.4, 0),
         ("grave-chapel", 160, 8.0, 0)]
for prop, bearing, size, bb in TRAIL:
    x, z = polar(CX, CZ, bearing, R - 6.0)
    L.append(place_at(prop, x=x, z=z, size=size, occluder=True, billboard=bb,
                      rotY=(None if bb else bearing + 180)))

# ── woodland: character, not cover ──────────────────────────────────────────────────────────────
for i in range(64):
    bearing = i * 5.625 + 2.0
    r = R + 14 + (i % 5) * 9          # outside the path, framing the circuit
    x, z = polar(CX, CZ, bearing, r)
    prop = "grave-frametree" if i % 3 else "grave-conifer"
    L.append(place_at(prop, x=x, z=z, size=9.0 + (i % 4) * 1.6, flip=(i % 2 == 0),
                      billboard=20 if prop == "grave-conifer" else 0))
for i in range(18):
    bearing = i * 20 + 11
    x, z = polar(CX, CZ, bearing, R - 20 - (i % 3) * 6)   # inside, on the hill's lower slopes
    L.append(place_at("grave-frametree", x=x, z=z, size=8.0 + (i % 3) * 1.4, flip=(i % 2 == 1)))

# ── graves and clutter along the way ────────────────────────────────────────────────────────────
STONES = ["grave-headstone-arch", "grave-headstone-cross", "grave-headstone-round",
          "grave-headstone-obelisk", "grave-headstone-slab"]
SIZES = {"grave-headstone-arch": 1.05, "grave-headstone-cross": 1.8, "grave-headstone-round": 0.75,
         "grave-headstone-obelisk": 2.2, "grave-headstone-slab": 0.95}
for i in range(56):
    bearing = i * 6.4 + 3.0
    r = R + (5.5 if i % 2 else -5.5) + (i % 3) * 1.7
    prop = STONES[i % 5]
    x, z = polar(CX, CZ, bearing, r)
    L.append(place_at(prop, x=x, z=z, size=SIZES[prop], flip=(i % 2 == 0),
                      rotY=bearing + 180 + (14 if i % 3 else -11)))

for side, flip in ((-1, True), (1, False)):               # gate piers at the start
    L.append(place_at("grave-gate-pier", x=side * 3.6, z=1.0, size=3.2, flip=flip))

for i in range(14):
    bearing = i * 25.7 + 8
    x, z = polar(CX, CZ, bearing, R + (3.6 if i % 2 else -3.6))
    prop = ("grave-pumpkins", "grave-pumpkin-single", "grave-candles")[i % 3]
    L.append(place_at(prop, x=x, z=z, size=0.42 if i % 3 == 0 else 0.4,
                      billboard=15 if i % 3 < 2 else 0))

for i in range(72):                                        # verges
    bearing = i * 5
    for dr in (-3.4, 3.4):
        x, z = polar(CX, CZ, bearing, R + dr)
        L.append(place_at("grave-grass", x=x, z=z, size=0.34, flip=(i % 2 == 0), billboard=30))

for bearing in (44, 133, 251, 318):                        # ghosts over the slopes
    x, z = polar(CX, CZ, bearing, R - 16)
    lay = place_at("grave-ghost", x=x, z=z, size=1.15, billboard=60)
    lay["y"] = round(lay["y"] + 2.2, 3)
    L.append(lay)

L.sort(key=lambda l: l["z"])

out = {
    "name": "graveyard-ring",
    "meta": {"source": "backdrop.graveyard.spooky.fun.png", "built_by": "gy/ring.py",
             "fog": {"color": "#2f3854", "background": "#202555", "density": 0.0055}},
    "floorY": FLOOR_Y, "lens": LENS,
    "cam": {"x": R + 14, "y": 1.1, "z": 2 * R + 14, "pitch": 70,
            "ring": {"x": CX, "z": CZ, "r": R, "w": CORRIDOR}},
    "layers": L,
}
os.makedirs(SCENES, exist_ok=True)
p = os.path.join(SCENES, "graveyard-ring.json")
json.dump(out, open(p, "w"), indent=1)
occ = sum(1 for l in L if l.get("occluder"))
print(f"{p} — {len(L)} layers, {occ} occluders")
print(f"  path radius {R:.0f} m, circumference {2*math.pi*R:.0f} m "
      f"(~{2*math.pi*R/2.4/60:.1f} min at walking pace), corridor {CORRIDOR:.0f} m wide")
print(f"  house {HOUSE_H:.0f} m on a {HILL_H:.0f} m hill: "
      f"{HOUSE_H/(0.676*R)*100:.0f}% of frame height, {2*math.degrees(math.atan(5.5/R)):.1f} deg wide")
