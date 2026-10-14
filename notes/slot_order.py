#!/usr/bin/env python3
"""Does the ORDER of a prompt's recipe slots change what the model obeys?

DataDungeon's recipes split a picture prompt into named slots. Nobody publishes an order for
them (see notes/prompt-slot-order-v1.md), and the orders in play contradict each other: Google's
image examples append lighting last, its text guidance puts constraints FIRST, and edit models
want preservation constraints last.

Run on klein (FLUX.2 Klein 9B) because it is the ONLY camera that honours a seed, so the order is
the only thing that moves between two pictures in a pair. Four arrangements of the same slot
CONTENT, three subjects, three seeds.

Scored two ways:
  - by machine, on the framing rule ("solid pure black background, nothing else in frame"):
    border purity and the share of pixels that are not background. No judgement involved.
  - by eye, on the no-signage rule and on style/theme fidelity. The contact sheet is BLIND:
    filenames are hashes, and only the manifest says which cell is which.

    slot_order.py seedcheck    # 2 calls: prove the seed engages on klein before trusting any pair
    slot_order.py run          # 36 calls
    slot_order.py score        # machine scores + contact sheet, no API calls

About $0.22 all in at klein's $0.0059. Needs RUNWARE_API_KEY.
"""
import hashlib, json, os, sys, uuid, urllib.request
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from PIL import Image

KEY = os.environ["RUNWARE_API_KEY"]
MODEL = "runware:400@2"  # klein. seeds: true (the only one)
STEPS, CFG = 20, 3.5     # klein's own extra, from src/arcana/cameras.cr
SIZE = 1024
SEEDS = [31337, 8675309, 141421]
OUT = os.path.expanduser("~/.local/share/mj/experiments/slot-order-v1")

# Slot content, held FIXED across arrangements. Whole sentences with their own end punctuation,
# joined with one space, as DataDungeon's recipes specify.
#
# `rating` and `framing` are deliberately separate. DataDungeon's `rules` slot is RATING rules
# (Thomas, 2026-10-14) — a policy. mj's framing constraint is the other thing that has always sat
# last in our prop prompts, and arrangements E and F differ ONLY in where it goes.
SLOTS = {
    "rating":  "Suitable for all ages. No text, letters, numbers or signage anywhere in the image.",
    "theme":   "A seaside boardwalk amusement park, weathered by salt air.",
    "style":   "Clean cartoon game-prop art.",
    "framing": "Centred, filling most of the frame, on a solid pure black background, nothing else in frame.",
    "light":   "Lit from above.",
}

SUBJECTS = {
    # Signage pressure rises down this list: a barrel invites none, a ticket booth invites it badly.
    "barrel": ("A colourful wooden circus barrel with metal hoops.",
               "Painted red and gold, the hoops dulled and freckled with rust."),
    "cart":   ("A two-wheeled popcorn cart with a domed glass hood.",
               "Cream and cherry striped, a brass kettle inside, a folded parasol at the back."),
    "booth":  ("A small octagonal ticket booth with a scalloped awning.",
               "Turquoise panels, brass fittings, one shuttered window."),
}

# Each arrangement is the order its slots are joined in.
#   A — DataDungeon's original: ... style, rules, staging(light). What shipped before 0.13.
#   B — what I argued for: staging mid, rules last.
#   E — Thomas's, from the research: rating first, style abutting the subject, light last.
#   F — E with the framing constraint hoisted to the front beside the rating rules. E vs F is the
#       one clean test of Google's "constraints at the very beginning" against our rules-last.
ARRANGEMENTS = {
    "A": ["subject", "description", "theme", "style", "rating", "framing", "light"],
    "B": ["subject", "description", "framing", "light", "theme", "style", "rating"],
    "E": ["rating", "theme", "style", "subject", "description", "framing", "light"],
    "F": ["rating", "framing", "theme", "style", "subject", "description", "light"],
}


def compose(arrangement, subject_key):
    subject, description = SUBJECTS[subject_key]
    bag = dict(SLOTS, subject=subject, description=description)
    return " ".join(bag[slot] for slot in ARRANGEMENTS[arrangement])


def cell_id(arrangement, subject_key, seed):
    """Blind filename: the sheet must not tell the judge which arrangement made which picture."""
    return hashlib.sha256(f"{arrangement}/{subject_key}/{seed}".encode()).hexdigest()[:10]


def generate(prompt, seed, path):
    body = {"taskType": "imageInference", "taskUUID": str(uuid.uuid4()), "model": MODEL,
            "positivePrompt": prompt, "width": SIZE, "height": SIZE,
            "steps": STEPS, "CFGScale": CFG, "seed": seed,
            "outputType": "URL", "outputFormat": "PNG", "includeCost": True}
    req = urllib.request.Request("https://api.runware.ai/v1",
                                 data=json.dumps([body]).encode(),
                                 headers={"Content-Type": "application/json",
                                          "Authorization": f"Bearer {KEY}"})
    d = json.load(urllib.request.urlopen(req, timeout=300))["data"][0]
    urllib.request.urlretrieve(d["imageURL"], path)
    return float(d.get("cost") or 0.0)


def seedcheck():
    """Runware silently accepts unknown fields, so a 200 is not evidence the seed engaged.
    Same prompt, same seed, twice: identical pixels or the seed does nothing here."""
    os.makedirs(OUT, exist_ok=True)
    prompt = compose("E", "barrel")
    spend = 0.0
    for i in (1, 2):
        spend += generate(prompt, SEEDS[0], f"{OUT}/seedcheck-{i}.png")
    a, b = (np.asarray(Image.open(f"{OUT}/seedcheck-{i}.png").convert("RGB")).astype(float)
            for i in (1, 2))
    diff = float(np.abs(a - b).mean())
    print(f"same prompt, same seed, twice: mean abs pixel diff {diff:.4f}")
    print("  seed ENGAGES — pairs are comparable" if diff < 0.5 else
          "  seed DOES NOTHING on this model — every pair also differs by sampling noise,")
    print(f"  cost ${spend:.4f}")
    return diff < 0.5


def run():
    os.makedirs(OUT, exist_ok=True)
    cells = [(a, s, seed) for a in ARRANGEMENTS for s in SUBJECTS for seed in SEEDS]
    manifest, spend = {}, 0.0

    def one(cell):
        a, s, seed = cell
        cid = cell_id(a, s, seed)
        prompt = compose(a, s)
        cost = generate(prompt, seed, f"{OUT}/{cid}.png")
        return cid, {"arrangement": a, "subject": s, "seed": seed,
                     "prompt": prompt, "cost": cost}

    # Four at a time: Runware publishes guidance of 2-4 concurrent (src/arcana/pool_limit.cr).
    with ThreadPoolExecutor(max_workers=4) as pool:
        for cid, row in pool.map(one, cells):
            manifest[cid] = row
            spend += row["cost"]
            print(f"  {cid}  {row['arrangement']}/{row['subject']}/{row['seed']}  ${row['cost']:.4f}")

    with open(f"{OUT}/manifest.json", "w") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
    print(f"\n{len(manifest)} images, ${spend:.4f}, manifest written")
    print("NOT in mj's spend ledger: this calls Runware directly, not through mj.")


def score():
    """The framing rule is machine-checkable: the background is meant to be solid pure black
    with nothing else in frame. Report numbers, let Thomas judge the pictures."""
    manifest = json.load(open(f"{OUT}/manifest.json"))
    rows = []
    for cid, row in manifest.items():
        im = np.asarray(Image.open(f"{OUT}/{cid}.png").convert("RGB")).astype(float)
        border = np.concatenate([im[0], im[-1], im[:, 0], im[:, 1]])
        # "solid pure black": how far the border is from black, and how much of the frame is lit.
        rows.append({"cell": f"{row['arrangement']}/{row['subject']}/{row['seed']}",
                     "arrangement": row["arrangement"],
                     "border_mean": float(border.mean()),
                     "border_max": float(border.max()),
                     "lit_share": float((im.mean(axis=2) > 24).mean())})

    by = {}
    for r in rows:
        by.setdefault(r["arrangement"], []).append(r)
    print(f"{'arr':>4}  {'border mean':>11}  {'border max':>10}  {'lit share':>9}   n")
    for a in sorted(by):
        rs = by[a]
        print(f"{a:>4}  {np.mean([r['border_mean'] for r in rs]):11.3f}  "
              f"{np.mean([r['border_max'] for r in rs]):10.1f}  "
              f"{np.mean([r['lit_share'] for r in rs]):9.3f}   {len(rs)}")
    print("\nborder mean/max near 0 = the solid-black rule was obeyed. lit share is how much of"
          "\nthe frame the subject fills — context, not compliance.")

    # Blind contact sheet: 6 columns, hash under each tile, no arrangement anywhere.
    cids = sorted(manifest)
    cols, tile = 6, 320
    rowsn = (len(cids) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tile, rowsn * (tile + 14)), (18, 18, 18))
    for i, cid in enumerate(cids):
        im = Image.open(f"{OUT}/{cid}.png").convert("RGB").resize((tile, tile))
        sheet.paste(im, ((i % cols) * tile, (i // cols) * (tile + 14)))
    sheet.save(f"{OUT}/contact-sheet.png")
    print(f"\nblind contact sheet: {OUT}/contact-sheet.png")
    print(f"order of tiles (left to right, top to bottom): {' '.join(cids)}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "seedcheck":
        raise SystemExit(0 if seedcheck() else 1)
    elif cmd == "run":
        run()
    elif cmd == "score":
        score()
    else:
        print(__doc__)
