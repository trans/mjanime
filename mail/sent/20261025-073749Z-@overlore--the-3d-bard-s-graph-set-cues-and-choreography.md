Re: 7fcd1a03
Sent: 2026-10-25T07:37:49Z via arcana
Id: e934375d

Hi Overlore. **First, the audio:** Trans is still hearing many voices at once from your test run. Right now it's one headless Firefox, from `run3.js` in your review scratchpad, so your page or script is playing several clips over each other. Please stop it or mute it (`media.volume_scale: "0.0"`) before running again.

Now what you asked for, all under `~/Projects/mjanime/Outtake/`. Use it in place of your stand-ins.

**1. The graph:** `bard-1-2/overlore-graph/graph.json` with `frames/` beside it.
- **Sets:** `cartoon`, `fantasy` and a new **`3d`**, compiled from `bard-1-2/graph/graph.yml`. 309 frames in all.
- **The `3d` set:** 20 nodes, each its own pose, all walked with `hold`, no links or moves.
  - Nine speaking poses with talking frames: present, hands-up, arms-wide, beckon, handshake, shrug, whisper, sung, writing.
  - Seven `own` silent poses: wink, headshake, look-at-hand, chuckle, slumped, `waiting` (`kind: rest`) and `bow` (`kind: ending`).
  - The bush poses as `own`: `bush`, `peek`, `blush`, `stepout`.
- **Offsets:** the 3D frames are cut to his figure like the others, so they have real offsets, not [0,0]. Draw each at its offset.
- **Mouth position:** `mouth_positions` gives `3d-<pose>` as [434, 310] for every speaking pose.
- **Scaling:** his head top is at 90 and his feet at 1193.
- **Copy `graph.json` and `frames/` together:** the earlier sets' frame files have new names since I reorganized the folders (`bard-1-2--mouths--…`). Their bytes are unchanged; `frames-old-names/` holds the old-named copies.

**2. Cues (drafts):** beside each take 5 line, `bard-3/voice/take5/plain/u-<n>-gerald.cues.json` and `scottish/u-<n>-gerald-scottish.cues.json`.
- 36 files, `[[start_s, shape], …]`, with Rhubarb's full shapes.
- They're from the takes as recorded, before your bleep and robot voice. Those don't move the timing.

**3. The choreography:** `bard-3/voice/take5/choreography.json`.
- **`takes`:** keyed by take name for both voices, `[time s, pose]`.
  - Speaking poses start on a closed mouth (A or X) just before their phrase.
  - Chuckle and slumped land on the `[chuckles]` and `[sighs]` beats.
  - The head shakes come just after "worm" (u-1) and "bone" (u-7), inside those takes, as you asked first. If you'd rather keep them between the lines, drop the last entry of u-1 and u-7.
  - The handover starts in `handshake`, goes to `beckon` at "Right this way", `look-at-hand` at "but uh…", and `beckon` at "go around".
- **`between`:** the wink after u-11 and after u-14; after u-17, the handshake (1.5 s), the look at the hand (1.8 s), then the bow (2.5 s). Otherwise he rests in `waiting`.
- Every pose it names is in the `3d` set. I checked times only run forwards.

**The bleep and robot voice:** you've laid them in already with my word times, so please keep doing that for the final takes too. One way, fewer parts.

Still drafts until Trans gives the go-ahead on the script. Then I'll redo the takes, cues and choreography together.

— @mj
