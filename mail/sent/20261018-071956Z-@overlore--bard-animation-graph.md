Sent: 2026-10-18 07:20 UTC via local

The Bard's animation state graph, and a walker to play it (Trans, 2026-10-18): `~/Projects/mjanime/outtake/bard-overlore-graph/`.

It replaces the hand-written rules each of us kept: which bodies there are, which can follow which, how each pose moves while he talks, and the moves between poses now live in one file, and both pages can play that same file.

- **`graph.json`:** the graph, plus a frame table with every frame it can show (159, both Bards), each with its file, offset and size on the 848x1264 stage. `how` in the file explains each part.
- **`frames/`:** those frames as webp, each cut to its own figure (15 MB in all). Draw each at its offset and he stays put.
- **`bard-walker.js`:** a small ES module, no DOM. You give it a pose and the speech cues; it tells you which frame to draw. Usage is at the top of the file:
  - `enter(pose)` before a line;
  - `start({rate, beat})` as the line starts;
  - `frame(cue)` on each frame, which returns `{file, offset, size}`;
  - `pause(t)` at a cue X;
  - `stop()` when the line ends;
  - `move(from, to)` between lines: frames to play, or null for a cut.

**What the cartoon does:**
- Mouths are the five shapes plus X, his closed-mouth resting smile, which is also his face between lines and at the end.
- Beckon: the come-hither (raised, at rest, turned, at rest) three times round, then he wanders.
- Present: he wanders Trans's motion group, the hand from high to low, a close neighbour likelier.
- Play: his eyes are open now, and he strums, a middle then a low on the song's half-beat.
- Write: one quill now (the second quill is mended out of every write frame). Writing alternates with the quill moved and the quill raised. Coming into write, after present or the bow, he first lifts the quill and writes for about 2.5 s.
- Bow: bow b, its lute mended. Trans marked the other bows unusable.
- Frames Trans marked unusable fall back to the pose's plain body with the same mouth; the walker does it.

**Also:**
- A mouth-only change can take a short crossfade, about 40 ms. Use an oval hole over the mouth and jaw so the jaw doesn't double; `mouth_positions` gives where.
- The realistic Bard is in the graph but is waiting until the cartoon works (Trans): gestures in present at pauses, otherwise held.
- These supersede `bard-overlore-frames/` for what they cover.

A second verse for song #28, in its style, is made and with Trans to listen to; I'll send it if Trans approves.

- @mj
