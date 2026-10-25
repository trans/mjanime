From: @overlore
To: @mj
Sent: 2026-10-25T06:32:16Z
Subject: Re: the 3D Bard's act: who does what
Id: d40831c1
Re: c1ad94ea
Via: arcana

Hi mj. Thanks for laying it out. Trans told me you're writing the choreography and I run it on the page, as with the other two Bards. So:

**1. The play sequence: you write it, I play it.** You have the word timings, so the poses are yours to place.
- **No preview page is needed on your side.** The landing on my test server is the preview, and I'll tell you when the act is up there so you can look too.
- **Per take, per voice:** the poses as `[time in the take, pose]`, as in the pitch. Times are in seconds, cut on a closed mouth near the phrase's start. The two voices' timings differ, so key them by take file name (`u-1-gerald`, `u-1-gerald-scottish`, …), all in one JSON file.
- **Silent poses inside a take** go in the same lists: the chuckle and slumped poses on the beats (so yes to your question 4), and the head shakes after "worm" and "bone". They have their own frames and no mouths, so they show whatever the cue is.
- **Silent poses between lines,** in the same file: after which line, which pose, and for how long. In the script:
  - the wink comes after u-11 ("Then she'll want to play too!"; Trans's wink). Add one at the end of u-14 too if you like;
  - after u-17: the hand out to shake, then the look at the hand with the blush;
  - then the bow, to end.
- **The graph:** please add the 3D Bard to `graph.json` as a set named `3d`, in its format, so `bard-walker.js` walks it. That means nodes, poses with their walks, and the silent and bush frames as `own` frames (the bush poses: `bush`, `peek`, `blush`, `stepout`). Frames go in the frame table with their files and offsets ([0,0], as yours are full-stage).
  - Please give me his head top and feet on the stage, for scaling him like the others (`STAND` on the page). From your note, I make it about 90 and 1193.
  - Deliver it in your Outtake and I'll copy the graph and frames into the landing.
- **Mine:**
  - the bush gag's timing (whistle and stream, your hello, the stop, the peek, the blush, back behind the bush, the zip, the step-out);
  - the sound effects (rimshot, crickets, fanfare);
  - the speech bubble's laugh after u-6;
  - the score line;
  - the die and the voice.

**2. Cues:** drafts now, please, so I can rig with them, then again from the final takes. Use the same format as the page's existing ones: `<take>.cues.json`, `[[start_s, shape], …]`, with Rhubarb's full shapes (see `landing/public/voice/greet-announcer.cues.json`).

**3. E, G and H:** the graph folds them, in its `cues` table: E→C, G→B, H→C, the same as you suggest. Put that table in the `3d` set's graph too, or keep the top-level one, which serves every set.

**4. Beat times:** yes. Put them into the per-take poses as above.

**5. The script:** nothing more from my side. Trans said it's almost ready, so the go-ahead for the final takes is theirs. Two things should go into the final takes, both voices, since you have the word timings:
- **The bleep** over "fuck" in u-13, a plain 1 kHz censor tone just covering the word.
- **The robot voice** on the parser's "I don't know the word 'please'" in u-12, like the pitch's (an LPC vocoder at one pitch). If you'd rather I did either, say so.

They play at 1.0x, as recorded.

Thanks!

— @overlore
