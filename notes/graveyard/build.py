#!/usr/bin/env python3
"""Build prop dirs (template.png + prop.yml) for the graveyard diorama cast.

Each prop's template IS a crop of the source image, padded onto the key colour at a
target coverage -- the crop is the style/geometry reference, not a cutting mask.
"""
import os, subprocess, textwrap

CROPS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "crops")
PROPS = os.path.expanduser("~/.local/share/mj/props")

MAGENTA = "#FF00FF"
BLACK = "#000000"
WHITE = "#FFFFFF"
RGB = {MAGENTA: [255, 0, 255], BLACK: [0, 0, 0], WHITE: [255, 255, 255]}

STYLE = ("Painterly Halloween storybook style, spooky but fun, cool moonlit blue-grey "
         "shadows with warm amber accents, crisp foreground clarity with no fog or haze. "
         "Photographed straight on at ground level with a long lens.")


def isolate(bg):
    colour = {MAGENTA: "pure magenta", BLACK: "pure black", WHITE: "pure white"}[bg]
    return (f"It floats isolated on a solid {colour} background -- no ground, no grass, "
            "no other objects, nothing else in frame.")


# name, ref crop, bg, W, H, coverage(frac of the long side), key_low, key_high, despill, subject
CAST = [
    ("grave-chapel", "r-chapel", BLACK, 1024, 1024, 0.70, 4, 26, False,
     "a small gothic revival stone mausoleum chapel with a steep gabled roof, a rose window, "
     "slender corner pinnacles, a stone cross on the peak, and a tall arched doorway glowing "
     "warm orange from within"),

    ("grave-conifer", "r-conifer", MAGENTA, 768, 1376, 0.80, 9, 30, True,
     "a single tall narrow spruce tree with dense drooping dark blue-green boughs and a "
     "pointed top, silhouette-like but with readable needle detail"),

    ("grave-deadtree", "r-deadtree", MAGENTA, 1024, 1024, 0.86, 9, 30, True,
     "a single gnarled leafless dead tree with a thick twisted trunk and long bare clawing "
     "branches spreading up and to the right, rough dark bark"),

    ("grave-headstone-cross", "r-cross", MAGENTA, 1024, 1024, 0.62, 9, 28, True,
     "one weathered Celtic cross grave marker of grey stone -- a ringed cross head with carved "
     "knotwork on a tapered plinth, chipped and lichen-spotted"),

    ("grave-headstone-slab", "r-headstone", MAGENTA, 1024, 1024, 0.55, 9, 28, True,
     "one flat rectangular grave tablet of dark grey stone, leaning noticeably to the left, "
     "square-topped, worn smooth with a faint illegible inscription and moss along the base"),

    ("grave-headstone-obelisk", "r-headstone", MAGENTA, 1024, 1024, 0.72, 9, 28, True,
     "one tall broken stone obelisk grave monument on a stepped square base, snapped off at a "
     "jagged angle near the top, pale weathered granite streaked with dark water stains"),

    ("grave-headstone-round", "r-headstone", MAGENTA, 1024, 1024, 0.48, 9, 28, True,
     "one small squat round-topped headstone of dark mottled stone, sunk slightly into the "
     "earth and tilted back, its inscription completely worn away"),

    ("grave-crypt", "r-crypt", MAGENTA, 1024, 1024, 0.72, 9, 28, True,
     "a small square stone crypt with a pyramidal roof, a slender finial, and a dark arched "
     "opening on the front face, pale weathered ashlar blocks with moss in the joints"),

    ("grave-fence", "r-fence", MAGENTA, 1376, 768, 0.88, 9, 26, True,
     "a straight section of black wrought-iron cemetery fence -- slender vertical spear-tipped "
     "bars with two horizontal rails and a stone kerb footing, seen square on"),

    ("grave-pumpkin-single", "r-pumpkin1", BLACK, 1024, 1024, 0.62, 4, 26, False,
     "a single carved jack-o'-lantern, a deep orange ribbed pumpkin with a curled green stem, "
     "triangular eyes and a jagged grinning mouth lit from inside by a warm candle glow"),

    ("grave-candles", "r-candles", BLACK, 1024, 1024, 0.60, 4, 26, False,
     "a cluster of three melted white pillar candles of different heights standing on a small "
     "mossy stone ledge, each with a warm burning flame and long wax drips"),

    ("grave-ghost", "r-ghost", BLACK, 768, 1376, 0.72, 4, 24, False,
     "a small friendly cartoon ghost of glowing translucent cyan light -- a rounded head with "
     "big dark eyes and a soft trailing wispy tail instead of legs, hovering"),

    ("grave-crow", "r-crow", WHITE, 1024, 1024, 0.60, 4, 28, True,
     "a single glossy black crow perched on a short bare branch stub, head turned to face the "
     "viewer, blue-white moonlight rim along its back and folded wings"),

    ("grave-bats", None, WHITE, 1376, 768, 0.0, 4, 28, True,
     "a loose scatter of five small bats in flight at different sizes and angles, dark "
     "silhouettes with spread membrane wings, arranged across the frame"),

    ("grave-grass", "r-grass", MAGENTA, 1376, 768, 0.80, 9, 30, True,
     "a low clump of ragged graveyard grass and weeds -- tufted blades, a few dry seed stalks "
     "and a scatter of small stones, wider than it is tall, seen from ground level"),
]


def build(name, ref, bg, W, H, cover, klo, khi, despill, subject):
    d = os.path.join(PROPS, name)
    os.makedirs(d, exist_ok=True)
    tpl = os.path.join(d, "template.png")

    if ref is None:
        subprocess.run(["magick", "-size", f"{W}x{H}", f"xc:{bg}", tpl], check=True)
    else:
        src = os.path.join(CROPS, ref + ".png")
        # scale the crop so its long side hits `cover` of the matching frame side
        subprocess.run([
            "magick", "-size", f"{W}x{H}", f"xc:{bg}",
            "(", src, "-resize", f"{int(W*cover)}x{int(H*cover)}", ")",
            "-gravity", "center", "-composite", tpl], check=True)

    prompt = (f"Redraw the subject from the reference image as a single isolated game prop: "
              f"{subject}. {STYLE} {isolate(bg)}")
    body = "\n".join("  " + l for l in textwrap.wrap(prompt, 96))
    yml = (
        "prompt: >-\n" + body + "\n"
        + f"background: {RGB[bg]}\n"
        + "auto_background: true\n"
        + f"key_low: {klo}\n"
        + f"key_high: {khi}\n"
        + f"despill: {str(despill).lower()}\n"
        + "defringe: true\n"
        + "edge_guard: 2\n"
        + "despeckle: 64\n"
        + "alpha_bleed: true\n"
        + 'model: "google:4@3"\n'
        + f"width: {W}\n"
        + f"height: {H}\n"
        + 'tags: ["graveyard", "halloween", "night"]\n'
    )
    with open(os.path.join(d, "prop.yml"), "w") as f:
        f.write(yml)
    return name


if __name__ == "__main__":
    for row in CAST:
        print(build(*row))
