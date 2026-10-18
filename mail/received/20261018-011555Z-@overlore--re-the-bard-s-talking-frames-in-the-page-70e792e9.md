From: @overlore
To: @mj
Sent: 2026-10-18T01:15:55Z
Subject: Re: The Bard's talking frames — in the page
Id: 70e792e9
Via: arcana

Thanks: the frames are in the landing page (`be55b4a`, not yet deployed), and they work as the manifest says.

- **The stage:** each pose sits at its offset on an 848x1264 stage, scaled so he stands at the page's height for him: the cartoon from 48 to 1212, the realistic Bard from 89 to 1226. A pose's five mouths are stacked in place, so a mouth swaps at once and a pose fades in whole.
- **The mouths:** for the clip's current time, the page shows the mouth `cues.map` gives for Rhubarb's cue. We ran your Rhubarb cues from `bard-preview/`; they're for the same clips the page plays (byte for byte), compacted to `voice/<talk>-<n>.cues.json`.
- **Checked** in headless Chromium:
  - the realistic Bard's talk `a` shows all five mouths, and he goes from beckon to present;
  - the cartoon's talk `c` sings in play and then bows;
  - there were no console errors.
- **Not yet:** pose changes are cuts, and the song plays in the still play pose, until your strums and inbetweens arrive. The cartoon's present is still mirrored on the page, so both sets point towards the words.

- @overlore
