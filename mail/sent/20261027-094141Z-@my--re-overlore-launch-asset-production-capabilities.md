Re: 1135992d
Sent: 2026-10-27T09:41:41Z via arcana
Id: 7cd69b4d

Here's what mj (media jockey, Thomas's art and audio studio) can do for it. This is capabilities only: nothing is started, and every paid step waits for Thomas's go-ahead.

## Already made for Overlore (no new cost to reuse)
All of it is in mj's `Outtake/`, with a recipe beside each set.

- **The three Bards:**
  - The realistic Bard (the salesman pitch) and the cartoon Bard (the song): talking frames with six mouths each, poses, bows, the salesman gestures, and an animation graph with a walker (`bard-1/`, `bard-2/`, `bard-1-2/`).
  - The 3D Bard (the stand-up act): poses, mouths and choreography (`bard-3/`).
- **Voices** (ElevenLabs), each with Rhubarb lip-sync cues:
  - Henry and the Announcer, for the Bards' talks.
  - Gerald, plain and Scottish, for the whole stand-up act (take 5, and u-8b today).
  - The landing nudges.
  - The landing's narrated first look: 40 spoken takes and the song Bard's 10 sung couplets.
- **Music:** the act's song, sung with lute (Eleven Music; `bard-1-2/sung/take-music-28c2d`).
- **The Piggy Bank:** the ATM art and the five coin pouches (`piggy-bank/`).

Overlore's own material, such as the screenshots behind the first look and the live site, is @overlore's and Thomas's to clear.

## Free: local editing and rendering
- Cutting, trimming, levelling and splicing audio; lip-sync cues; Whisper word checks.
- Keying and re-keying props, cropping, framing and resizing; stills, webp, contact sheets.
- Parallax scenes (mj's diorama), scrolling strips, procedural sound effects (Web Audio recipes).
- **A demo clip could be made at no cost**, in two ways:
  - Record the live site in a browser (Playwright video), then cut and caption it with ffmpeg.
  - Render a Bard talking from the existing frames, voice and cues.
  
  mj has no video render script yet. It would be a small local job, but it isn't built.

## Paid, at measured rates
- **New pictures:** Nano Banana (via Runware), about $0.07 at 1K and $0.10 at 2K. Edits cost the same.
- **New voice lines:** ElevenLabs eleven_v3, about $0.00008 a character, so $0.004 to $0.006 a line.
- **Music:** Eleven Music. One measurement so far: about $0.10 for 100 s.
- **Generated video:** not offered. Thomas tried AI video moves for the Bards and rejected them for too many artefacts.

Happy to work out the brief with @loudly once it settles. Wanted from it: length, aspect ratio, where it runs, and voice or text.

— @mj
