#!/usr/bin/env python3
"""Prove a Runware control parameter actually does something.

Runware SILENTLY ACCEPTS unknown top-level parameters. A 200 response is not evidence that a
control engaged -- during the infocomic work a deliberately invented field name ('pulid', wrong
case) was accepted without complaint and had no effect whatsoever. Two real bugs had been sitting
in production behind exactly that silence: arcana-ai's PuLID sent `referenceImages` +
`guidanceScale`, which Runware discards, so the identity method had never once engaged.

The only reliable test is A/B on a fixed seed. Generate twice, identical but for the parameter,
and diff the pixels. ~0 means ignored. Always include a deliberately bogus parameter as a control,
so you can tell "ignored" from "subtle".

    verify_param.py                 # runs the PuLID case as a worked example

Costs about a tenth of a cent per call on FLUX dev. Run it over every control parameter before
trusting any of them.
"""
import base64, json, os, sys, uuid, urllib.request
import numpy as np
from PIL import Image

KEY = os.environ["RUNWARE_API_KEY"]
MODEL = "runware:101@1"          # FLUX dev: cheap and fast enough to A/B freely
SEED = 31337


def _gen(prompt, extra, out):
    body = {"taskType": "imageInference", "taskUUID": str(uuid.uuid4()), "model": MODEL,
            "positivePrompt": prompt, "width": 1024, "height": 1024, "steps": 20,
            "CFGScale": 3.5, "seed": SEED, "outputType": "URL", "outputFormat": "PNG"}
    body.update(extra)
    req = urllib.request.Request("https://api.runware.ai/v1",
                                 data=json.dumps([body]).encode(),
                                 headers={"Content-Type": "application/json",
                                          "Authorization": f"Bearer {KEY}"})
    d = json.load(urllib.request.urlopen(req, timeout=200))["data"][0]
    urllib.request.urlretrieve(d["imageURL"], out)
    return out


def verify(prompt, candidates, workdir="/tmp"):
    """candidates: [(label, extra_params), ...]. Include a bogus one as a control."""
    base = np.asarray(Image.open(_gen(prompt, {}, f"{workdir}/vp-base.png"))
                      .convert("RGB")).astype(float)
    for i, (label, extra) in enumerate(candidates):
        a = np.asarray(Image.open(_gen(prompt, extra, f"{workdir}/vp-{i}.png"))
                       .convert("RGB")).astype(float)
        diff = float(np.abs(a - base).mean())
        print(f"  {label:<44} diff {diff:6.2f}   "
              f"{'IGNORED' if diff < 1.0 else 'engages'}")


if __name__ == "__main__":
    img = sys.argv[1] if len(sys.argv) > 1 else None
    if not img:
        print(__doc__); raise SystemExit
    uri = "data:image/png;base64," + base64.b64encode(open(img, "rb").read()).decode()
    verify("close up portrait of a man's face, comic book art", [
        ("arcana-ai's shape: referenceImages+guidanceScale",
         {"referenceImages": [uri], "guidanceScale": 1.0}),
        ("correct: puLID {inputImages, idWeight}",
         {"puLID": {"inputImages": [uri], "idWeight": 1.0}}),
        ("BOGUS CONTROL: 'pulid' lowercase",
         {"pulid": {"inputImages": [uri]}}),
    ])
