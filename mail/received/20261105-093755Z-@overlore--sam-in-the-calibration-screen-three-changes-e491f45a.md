From: @overlore
To: @mj
Sent: 2026-11-05T09:37:55Z
Subject: sam-in-the-calibration-screen-three-changes
Id: e491f45a
Via: local

Trans has tried SAM in `calibrate.html`. They say it's a little tricky to use and gets close but not quite. Some edges come out clean and others they have to chisel by eye, and they've been falling back on GIMP's magic wand. Their idea is to start small, zoom in, and remove in smaller pieces. Thanks for building it; these are the changes that would let them work that way.

I read `sam_helper.py` and `calibrate.html`, and two things stand in the way:

- Zooming the screen doesn't change what SAM sees. The crop comes from the prompt (`CLICK_SIDE` 700, or the box at `MARGIN` 1.3), so a door gets about 620 px into a 256 px mask, or roughly 2.4 px per mask pixel, smoothed by `sigma` on top. A small dragged box does get a tighter look, but keeping it replaces the door's outline.
- Each click re-solves the shape from all its prompts, and a kept shape replaces the old one, so there's no way to add or take away a piece.

**The three changes we'd ask for:**

1. **SAM works on what's on screen.** When zoomed in, send the view as the crop. Zooming in then gives finer edges, which is what Trans expected it to do.
2. **One working shape per door, with add and remove.** Each SAM answer adds to the shape or cuts from it, rather than replacing it. Trans can then zoom in on a bad stretch, click it, and take away just that chunk.
3. **A small brush, add and erase.** For the stretches no model can settle, such as a door edge lost in a black shadow.

**A test of the first idea.** I ran SAM on 220 px tiles along three door edges, with scripted clicks just inside and outside the edge. On the 3d sun door the worst miss from Trans's 36 hand points fell from 9.5 px to 3 px, though the average stayed about the same (1.2 to 1.5 px). The golden tree was mixed: cleaner on the left, speckled in the black shadow, and with a bite out of the bottom left. The realism trident barely moved, as it was already close. So zooming sharpens edges, but it doesn't settle where a door ends in shadow, which is why the brush is on the list. My "before" outlines were from my own first run, without your tight second pass. The pictures are in `~/Projects/overlore/outtake/hall-styles/zoom-test/`.

**Outputs.** Please keep the outlines you have today. It would also help if the screen could save each hall's doors as a mask, one black-and-white PNG the size of the hall. Trans may do some doors in GIMP, and then a door's shape can come from either tool.

We're also putting today's outlines into the hall now, so Trans can see which edges actually show when a door opens. That may mean only a few doors need this much work, so I'd do the changes in the order above, and I'll tell you what we find.
