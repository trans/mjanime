#!/usr/bin/env python3
"""The cow test: does a contradiction resolve by order, and does that depend on the model?

Usage: notes/cow_order.py [v1|v2]

Thomas's question (2026-10-14): "Draw a field. Draw a cow in the field. Don't draw a cow in the
field." against the same with the last two sentences swapped. Which wins?

Through mj:camera on the bus (the path Overlore uses), so spend lands in mj's ledger. Note that
mj's transport gives `klein` a flat grey canvas rather than true text-to-image
(src/arcana/transport.cr), as in production.

Three cameras, one per kind of model: `klein` (FLUX.2 Klein, diffusion), `nano` (Nano Banana 2,
Gemini), `flare` (GPT-Image 2.5). Only klein honours a seed, so its three runs are three seeds and
each pair differs ONLY in order; nano and flare get three plain repeats.
"""
import base64, json, os, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

BUS = "http://127.0.0.1:19118/request"
SIZE = 1024
SEEDS = [31337, 8675309, 141421]

# v1: the contradiction, both orders. v2: the negation alone, against a control with no cow
# mentioned at all, to tell "ignores don't" from "positive beats negative" (v1 had a positive
# "Draw a cow" in both prompts, so it could not separate them).
EXPERIMENTS = {
    "v1": {
        "neg-last": "Draw a field. Draw a cow in the field. Don't draw a cow in the field.",
        "pos-last": "Draw a field. Don't draw a cow in the field. Draw a cow in the field.",
    },
    "v2": {
        "neg-only": "Draw a field. Don't draw a cow in the field.",
        "field-only": "Draw a field.",
    },
}
VERSION = sys.argv[1] if len(sys.argv) > 1 else "v1"
PROMPTS = EXPERIMENTS[VERSION]
OUT = os.path.expanduser(f"~/.local/share/mj/experiments/cow-order-{VERSION}")
CAMERAS = ["klein", "nano", "flare"]


def shoot(camera, order, n):
    payload = {"tool": "shoot", "camera": camera, "prompt": PROMPTS[order],
               "width": SIZE, "height": SIZE, "format": "webp"}
    if camera == "klein":
        payload["seed"] = SEEDS[n - 1]
    body = json.dumps({"from": "@mj", "to": "mj:camera", "subject": "shoot", "payload": payload,
                       "timeout_ms": 240000}).encode()
    req = urllib.request.Request(BUS, body, {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=250) as r:
        reply = json.load(r)
    data = reply["payload"].get("data", reply["payload"])
    name = f"out-{camera}-{order}-{n}.webp"
    row = {"file": name, "camera": camera, "order": order, "run": n, "prompt": PROMPTS[order]}
    if data.get("status") == "ok":
        with open(os.path.join(OUT, name), "wb") as f:
            f.write(base64.b64decode(data["image_base64"]))
    row.update({k: v for k, v in data.items() if k not in ("image_base64",)})
    return row


def main():
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "prompt.txt"), "w") as f:
        for k, v in PROMPTS.items():
            f.write(f"{k}: {v}\n")
        f.write(f"\ncameras: {', '.join(CAMERAS)} via mj:camera shoot; {SIZE}x{SIZE} webp\n")
        f.write(f"klein seeds (run 1-3): {SEEDS}; nano and flare: no seed, three repeats\n")
        f.write("no negative prompt, no reference image\n")
    jobs = [(c, o, n) for c in CAMERAS for o in PROMPTS for n in (1, 2, 3)]
    with ThreadPoolExecutor(4) as pool:
        rows = list(pool.map(lambda j: _safe(*j), jobs))
    with open(os.path.join(OUT, "results.jsonl"), "w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")
    spent = sum(r.get("usd") or 0 for r in rows)
    for r in rows:
        print(r["file"], r.get("status"), r.get("usd"), r.get("error", "") or r.get("reason", ""))
    print(f"total usd {spent:.4f}")


def _safe(c, o, n):
    try:
        return shoot(c, o, n)
    except Exception as e:  # one failure must not lose the rest
        return {"file": f"out-{c}-{o}-{n}.webp", "camera": c, "order": o, "run": n, "status": "error",
                "error": str(e)}


if __name__ == "__main__":
    sys.exit(main())
