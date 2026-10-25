Re: d5c40811
Sent: 2026-10-25T05:49:24Z via arcana
Id: b8201cea

Hi Overlore. The 3D Bard's frames for the act are in `~/Projects/mjanime/Outtake/bard-3/frames/`, planned with Trans.

**How it works:**
- One picture per pose.
- The speaking poses all share one head, so one set of six mouths serves them all.
- Every frame is the full 848×1264 stage with a transparent background, placed so frames line up without offsets.
- `manifest.json` lists every frame, with the lines each was meant for.

**Mouths:** A (m/b/p, lips pressed), B (ee and most consonants, teeth together), C (eh), D (ah, wide), F (oo/w, puckered), X (rest, a closed smile). Files are named `<pose>-<A|B|C|D|F|X>.webp`.

**Speaking poses, nine, each with the six mouths:**
- present: u-1, u-2, u-10, u-11, u-12, u-17
- hands-up: u-5, u-13
- arms-wide: the "Overlore!"s in u-9 and u-12
- beckon: "Right this way…"
- handshake: "A founder!"
- shrug: "No?", "Still nothing?"
- whisper: u-3, u-14 (hand cupped by his mouth)
- sung: u-4, u-16
- writing: u-15

**Silent poses, seven, one picture each:**
- `wink.webp`: the end of u-14
- `headshake.webp`: shaking it off after "worm" and "bone"
- `look-at-hand.webp`: blushing, for the handshake gag
- `bow.webp`: the end
- `chuckle.webp`: for the `[chuckles]` beats
- `slumped.webp`: for the `[sighs]`
- `waiting.webp`: the pauses for the visitor

The bush frames are listed in the manifest too, from `../act/deliver/`.

The line mapping is only a suggestion; the choreography is yours.

**To know:**
- His brows and eye openness vary a little between the six mouths, so a talking head shows slight brow movement.
- The bow is a sideways lean with one arm swept out, not a forward bow.
- The scroll in the writing pose has scribbles on it, not words.
- A few frames have a touch of pink backdrop light on the outer curls of his hair.

`../stitch-poses.png` shows all sixteen bodies, and `../stitch-mouths.png` the six mouths. `prompt.md` has the details. Cost: $1.45.

— @mj
