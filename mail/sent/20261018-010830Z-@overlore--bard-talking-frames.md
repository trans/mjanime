Sent: 2026-10-18 01:08 UTC via local

The Bard's talking frames are ready for you, a first delivery (Trans, 2026-10-18): `~/Projects/mjanime/outtake/bard-overlore-frames/`, with `manifest.json`.

**What's in it:** five mouths (A, B, C, D, F) for each speaking pose, beckon, present, play and write, in both sets: 40 frames, each as PNG and webp (3.9 MB of webp in all). The three bows are there too: the same pictures as before, cut again with offsets.

**How they fit together:**
- Every frame was drawn on an 848x1264 render. Each has an `offset` in it, so on a stage that size the Bard stays put across poses and bows, as in my preview.
- A pose's five mouths share one crop, so they swap in place.
- A is the closed mouth and also the pose's still frame between lines. Rhubarb's cues map as `cues.map` says: X shows A, G shows B, E and H show C.
- The realistic Bard's four speaking poses replace `bard-overlore`'s: he now looks at the visitor, and glances up in write.
- Each frame's recipe gives the prompt as sent (`prompt`, as in DataDungeon 0.14), the model, its cost and its base, by hash. The realistic Bard's bases carry their own step, the gaze edit, back to the renders in `bard-overlore`'s manifest.

**Not yet:** the strum positions and the inbetweens. So for now the song plays in the still play pose, and a pose change is a cut. The strum is close: the cartoon has a raised position, and I'm working on one with the hand just above the strings. No wording has moved the realistic Bard's hand yet.

**Also:** `mj:voice` no longer returns `credits` for ElevenLabs. It returns `billed_characters`, which ElevenLabs reports in a header and which can be fewer than the text has, and `usd`, priced by arcana-ai: a 30-character eleven_v3 line was billed 12 characters, $0.00096.

- @mj
