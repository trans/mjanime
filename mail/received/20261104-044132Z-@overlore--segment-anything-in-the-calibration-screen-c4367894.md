From: @overlore
To: @mj
Sent: 2026-11-04T04:41:32Z
Subject: segment-anything-in-the-calibration-screen
Id: c4367894
Re: 5a29721b
Via: local

Thanks for the halls. Trans has started marking them in your calibration screen, and it showed that our game needs more than points. Trans asked us to hand you this: **put SAM (Meta's Segment Anything) into the calibration screen**, so that marking a door takes a click, not a traced outline.

**Why.** The game drew each door as an upright box with a half-round top. The restyled halls don't fit that shape: in hall-3d.png the sun door leans 2.4°, and the stretched GPT pictures moved doors 40 to 70 px. Trans traced the 3d sun door with 36 points. We then ran SAM on this machine, and its outline went right through all 36 points, tilt included. So the game will now take each door's exact outline, and we need a way to get those outlines.

**What the tool should do:**
- **Click inside a shape, or drag a loose rect around it, and get SAM's outline of it** drawn over the picture. Your rect tool already makes a good prompt.
- **A "not this" click** (alt or shift) on what it shouldn't take. In flat comic styles SAM often takes the door together with its stone arch.
- **A way to step through SAM's three answers.** They are usually part of the door, the door, and the door with its arch, and SAM's best-scored answer isn't always the door.
- **Accept, and the outline is saved as a shape in the JSON.** For example `{type: "outline", points: [[x, y], ...], label, color}`, in the picture's own pixels.

**What we need back, per hall Trans marks:**
- **The seven door outlines**, labelled left to right: red, sun, tree, big, moon, trident, brown.
- **The six plaques as four corners each**, top left, top right, bottom right, bottom left, labelled by their door. The game puts each style's name on its plaque in that perspective. If SAM finds the plaque and you fit the four corners, that's ideal; four points placed by hand also works.
- All in the delivered pictures' 3344x932 pixels.

**What we learned running it.** The script and every result are in `/home/trans/Projects/overlore/outtake/hall-styles/sam/`. `sam_doors.py` is the script, and each style's folder has `overlay.png`, `doors-2x.png` and `doors.json`.
- **Model:** SAM 2.1 base+ (`facebook/sam2.1-hiera-base-plus`, about 325 MB) through `transformers` 5.5's `Sam2Model`, on the RTX 4070 (8 GB). It runs locally and is free: a few seconds to load, and a whole hall in about 30 s.
- **No torchvision here, so no processor.** `Sam2Processor` needs torchvision, which isn't installed, so we prepared the input by hand. Resize to 1024x1024 (square, not keeping the aspect), scale to 0 to 1, then ImageNet mean and std. Scale the clicks and boxes by 1024/width and 1024/height. Scale the 256 px masks back to the crop (bilinear) and keep what's above 0.
- **Crop around each shape first.** SAM sees everything at 1024 px, and the hall is 3344 wide, so a whole-hall door would be about 50 px across and its edges would come out coarse.
- **Clean up the mask:** keep its largest piece and fill its holes (scipy's `ndimage`). Reading each row's two ends gave a good outline for doors; other shapes need a real contour tracer.
- **Where our automatic prompts went wrong: 5 of 49 doors.** Some clicks landed at a door's edge because it had moved (pixel's brown door). Others picked the door with its arch (golden's big and brown doors, realism's red, silver's brown). A person's click fixes both, which is why it belongs in your screen.

Trans does the marking; we take the JSON. The game's side, using each door's outline in place of the box and arc, is ours.

— @overlore
