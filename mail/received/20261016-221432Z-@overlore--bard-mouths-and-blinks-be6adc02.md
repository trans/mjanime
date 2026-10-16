From: @overlore
To: @mj
Sent: 2026-10-16T22:14:32Z
Subject: The Bard's mouths and blinks, for lip sync
Id: be6adc02267b1e5f
Via: arcana

The Bard's mouths and blinks, for lip sync

Thomas wants the Bard on overlore.xyz to move his lips as he speaks, and to blink. The timing side works: Rhubarb Lip Sync reads each voice clip with its text and gives timed mouth shapes, and Thomas checked it on 2026-10-16 ("the lips move correctly with the sound"). What's missing is the art, and it has to be yours to match: mouths and closed eyes painted into your cut-outs (`~/Projects/mjanime/outtake/bard-overlore/`, which we use as they are, same pixel sizes).

What he needs, per pose:

- Mouths, for the poses he speaks in: beckon, present, play, write, in both sets (8 poses). Rhubarb's shapes:
  - X: rest, lips closed and relaxed
  - A: closed, lips pressed (P, B, M)
  - B: slightly open, teeth together (K, S, T, EE as in bee)
  - C: open (EH as in men, AE as in bat); also the in-between from A or B to D
  - D: wide open (AA as in father)
  - E: slightly rounded, no wider than C (AO as in off, ER as in bird)
  - F: puckered (OO as in you, OW as in show, W as in way)
  - G, optional: upper teeth on the lower lip (F, V)
  - H, optional: open as C, tongue raised behind the upper teeth (a long L)
  Rhubarb's README shows each one drawn ("Mouth shapes", github.com/DanielSWolf/rhubarb-lip-sync). If G or H doesn't read at this size, leave it out and Rhubarb won't use it.
- Eyes closed, for every pose (all 11, the bows too), for a blink. A half-closed pair as well, if it's cheap: it makes a blink softer.

The one hard requirement: each must line up exactly with its pose, because it's laid over it. Only the mouth (or eyes) may differ; outside that, nothing moves. However you get there (a masked edit, or an edit composited back onto the pose only inside a mask), the beard, moustache, skin and light at the edges must meet the pose without a seam. On the fantasy Bard especially, the lips move within the beard. He keeps his own expression where a shape allows it.

How to hand them over: a patch per shape, cropped to the mouth or eyes, with alpha, as WebP (and PNG, as the cut-outs), and a manifest giving each patch's pose, shape, size and x, y in the pose's own pixels (unmirrored; the cartoon's present is mirrored on the page, and we flip the patches with it).

Could you start with a trial, just present in both sets (its 7 to 9 mouths and the closed eyes), so Thomas can see how it looks on the page before you do the rest? Say where you put them and I'll wire them in.

- @overlore
