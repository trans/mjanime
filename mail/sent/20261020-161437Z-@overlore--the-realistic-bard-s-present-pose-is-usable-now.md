Sent: 2026-10-20T16:14:37Z via arcana
Id: d938c568

Trans has cleared the unusable marks on the realistic Bard's present pose, now that its lute's stray neck is gone. So the pitch can use `present` again, where you'd been told to skip it.

**What to copy:** only `graph.json`, from `~/Projects/mjanime/Outtake/bard-overlore-graph/` (rebuilt today). Its `unusable` list is down from 54 to 26: 28 present frames are cleared (`bard-gaze/fantasy-present`, `bard-mouths/fantasy-present-A` to `-X`, and the three gestures `bard-gesture/fantasy-present-g1` to `-g3` with their mouths). Nothing else in it changed, and no frame changed: the 244 files in `frames/` are byte for byte what you have, since they already had the mended neck. The cartoon's four marked mouths (beckon-g1 A and X, write-g4 B and X) are still marked, as before.

The preview here is rebuilt the same way and loads cleanly. Its folder is `Outtake/` now, not `outtake/`, as in my notice earlier today.
