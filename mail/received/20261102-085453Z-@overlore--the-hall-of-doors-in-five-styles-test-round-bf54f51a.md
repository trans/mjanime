From: @overlore
To: @mj
Sent: 2026-11-02T08:54:53Z
Subject: the-hall-of-doors-in-five-styles-test-round
Id: bf54f51a
Via: local

Trans asked for a test round: the hall of doors redrawn in five art styles, at PG.

**Why.** The onboarding is being redesigned. The hall's six side doors will each be an art style, with the style's name on the plaque above. You start in the hall as it is now, which is our fantasy style. Go through a door and you come back out into the same hall, drawn in that door's style. Whatever style you're standing in is your choice, and the big double door in the middle takes you on.

**The styles.** These are our wordings, from `data/art_styles.yml`:
- silver: "Silver Age comic: bold black ink outlines, flat limited colors, Ben-Day dots and halftone shading, 1960s Marvel/DC."
- realism: "Photorealistic: detailed textures, realistic proportions, as if photographed."
- 3d: "3D cartoon, sculpted and lit, rounded and exaggerated, like a still from a computer-animated feature film: rendered CGI, soft global illumination, subsurface scattering, smooth shading. It is a 3D render, not a drawing or a painting."
- manga: "Dark manga: black and white, heavy ink, detailed linework, screentone and cross-hatching, stark shadows, expressive eyes; one or two things picked out in color."
- pixel: "Chunky early to mid 16-bit pixel art: visible square pixels, limited palette, retro game aesthetic."

Fantasy is the current hall, so it needs nothing.

**The source.** The game uses `/home/trans/Projects/overlore/assets/props/backdrops/common/hall-of-doors.webp` (3344x932). That's rows 475-941 of `/home/trans/Projects/overlore/assets/_originals/Twin Fantasy Castle Halls.png` (1672x941), doubled in size. On October 11 we restyled the whole original and cut the same rows, which gives the model a normal shape to work with. Use whatever works best for you.

**What has to hold:**
- **All seven doors**, the six arched side doors and the big double door, in about the same places. Close is enough. Trans will mark where each image's doors and plaques are.
- **Each door clearly a door in its arch.** The game cuts each door out of the picture and swings it open.
- **The six plaques above the side doors stay blank.** The game letters them.
- **The floor in front of the big door stays clear.** The game writes "Embark" on its threshold.
- **The full width matters.** The player pans along a hall about two screens wide.

**What we learned on October 11.** The sheets are in `/home/trans/Projects/overlore/outtake/hall-styles/`.
- **"nano"** kept every door in place but barely changed 3D, realism and pixel. Comic was fair; manga needed a greyscale filter.
- **"hero"** restyled strongly but moved doors, and sometimes merged or dropped one.
- **A pixel filter** kept everything exactly where it was, but it looked like a mosaic, not pixel art.

The choice of model and method is yours, for example something that keeps the edges or the depth.

**What to send back:**
- each style at 3344x932, plus the uncut image it came from;
- a sheet of all six one above the other (fantasy too), for Trans to compare;
- what each one cost.

A test round, so one or two tries per style is plenty. G and R versions of each hall come later (Trans: PG for all first). The ones Trans picks will go into DataDungeon afterwards, so not yet.

— @overlore
