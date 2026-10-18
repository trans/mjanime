Sent: 2026-10-18 22:56 UTC via local

The realistic Bard's poses for the salesman pitch are ready. Trans chose the realistic Bard for the pitch, and the cartoon Bard stays on the song. They're in the graph package, rebuilt in the same folder: `~/Projects/mjanime/outtake/bard-overlore-graph/` (`graph.json`, `frames/`, `bard-walker.js`). The set is still `fantasy`.

**What's new in the `fantasy` set**

- 11 new poses: stand, point, spread, finger, count, robot, mind, heart, secret, thumbs and wink.
- **Same head throughout.** All of them except wink are arm changes to one picture of him, hands free and looking at the viewer, with the same talking heads pasted on. So cutting between these poses doesn't move his face.
- **The older poses have their own heads.** Beckon, write and bow come from his older pictures, so his face shifts a little when you cut to or from them.
- **Wink** is one frame of its own, with a winking face. Show it silent, after his last line.
- **Count** steps through one finger, two, then three. After `enter("count")` and `start()`, call `pause(t)` at each X cue, as for present. It moves on at most every 1.2 s and stays on three. This is a change in `bard-walker.js`: the rule "pause" now follows a pose's `order` when it has one, and otherwise steps at random as before.
- **Frames that changed:** in present, write and bow, the lute neck that stuck up above his shoulder is gone (Trans asked for it). Their frames and offsets changed, so please copy `frames/` and `graph.json` again.
- **Dropped:** patting the lute (Trans: the lute showed no neck).
- **Not yet usable:** present is mended, but Trans's unusable marks are still on it until they clear them. The map below leaves it out for now.

**Suggested pose for each line** (yours to change; the mouths follow your Rhubarb cues on your take, with the same shapes and cue map):

- Before he speaks, and between lines: stand.
- After "> Hello.":
  - "Hello, hello, come in, come in…": beckon
  - "mind the lute — mind the — lovely.": mind
  - "You're a bit early… a person of adventure —": point
  - "a person ready to drive home today in a brand new Overlore!": spread
- After "> What?":
  - "What? WHAT? My friend… human brain tissue!": spread
  - "Classic stock, pre-owned… little old wizard!": thumbs
  - "But this ain't your daddy's I.F.! Your daddy typed GO NORTH…": finger (pointing north)
  - "You? You just talk. Say it like you mean it…": point
  - "No more 'I don't know the word…'": robot, held through the robot voice. Trans: "fine, we'll see how it plays."
  - "But wait, there's more! Imagery! Oh, this baby has styles… plural!": finger, then spread
  - "Golden Age comic! Dark manga! Fantasy cover art!": count
  - "Why, it's a frackin' wardrobe for your eyeballs!": spread
  - "Plus your hero's portrait… upon completion!": stand
  - "It's Select-a-Quest… top to bottom!": spread
  - "Not enough? Dungeon Masters! Six of 'em, fighting over who gets you —": finger, then point
  - "beautiful, I cry every time.": heart
  - "Narrating your steps… that's what IIIIIII say!": thumbs
- "Speaking of which…":
  - "now, I shouldn't be doing this… my digital derriere.": secret
  - "But for you? I can put you down for an early-bird slot.": point
  - "Through the gates before the laggards, and the lagers.": spread
  - "All you gotta do is sign your email, right here…": write
- After the email:
  - "SOLD! To the adventurer with impeccable taste!": point
  - "Keep an eye out for my letter. It's been a pleasure.": bow
  - "And mind the grue on your way out!": thumbs, then the wink, silent

Everything else is as before. The stage is 848 x 1264, and you draw each frame at its offset.
