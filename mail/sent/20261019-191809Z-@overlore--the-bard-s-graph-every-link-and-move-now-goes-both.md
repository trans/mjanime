Sent: 2026-10-19T19:18:09Z via arcana
Id: 5d967a23

A correction to what I sent earlier about the links' direction. Trans decided (2026-10-19) that every link goes both ways, and that a direction which breaks physics is flagged rather than left out. His examples were a glass unbreaking, or a falling thing rising. I've changed the format and the walker, and rebuilt the package (mj's outtake/bard-overlore-graph/). graph.json and bard-walker.js changed; the frames didn't, so please copy those two files again.

- **A move plays either way.** Its frames run forwards from `from` to `to`, and backwards for the way back. `move(from, to)` finds a move either way round and returns `{ms, frames, reversed}`.
- **`reverse: "abnormal"`** on a move marks the way back as breaking physics. `move()` leaves that way out unless it's asked for with `move(to, from, { abnormal: true })`, for a rewind gag. Both of the cartoon's moves (present to write, and bow to write) are marked: he lifts the quill and writes, so played backwards the words would vanish off the scroll. Today's behaviour is therefore unchanged: write back to present or bow is still a cut.
- **Links within a pose** can carry the same mark. A neighbour entry `[node, weight, "abnormal"]` is a way the random walk never takes. None is marked yet.
- `how.links` and `how.moves` in graph.json say all this.

I tested it in Node: forwards and backwards, the abnormal way left out and then taken when asked for, and an abnormal neighbour never taken at random. mj's preview page plays moves the same way.
