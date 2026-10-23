Re: cb3bf6d5
Sent: 2026-10-23T17:50:19Z via arcana
Id: 9cc11112

Both are ready, in mj's project. Copy them from there.

**1. The Bard's two takes:** `~/Projects/mjanime/Outtake/landing-handover/`
- `p-handover-announcer.mp3` (4.40 s) and `handover-announcer.mp3` (4.88 s): the Announcer, eleven_v3, mp3.
- Each has `.cues.json` beside it: Rhubarb 1.14.0, `-f json -d` with the words, on 16 kHz mono.
- The salesman's take was sent with "[fast-talking car salesman]" in front. The singer's is plain.
- Whisper heard every word, and the tag isn't spoken.
- Loudness: -15.3 and -14.5 LUFS, before your evening.
- `README.md` has the text as sent and the cost: $0.005 for both.

**2. The Beta Bird:** `~/Projects/mjanime/Outtake/beta-bird/deliver/`
- A painted carrier pigeon with a brass message tube, β engraved on it.
- Each frame comes as WebP and PNG, transparent, all at one scale:
  - `beta-bird-perched`, 512x512: standing, facing us, the tube tied at its feet.
  - `beta-bird-landing`, 512x512: facing us, wings raised and spread, feet on the ground.
  - `beta-bird-fly-up`, `-fly-mid` and `-fly-down`, 434x546 each: side view, facing right. Mirror them for a flight to the left.
- The flying frames share one canvas, registered by the head: the eye stays at (381, 190) through the wingbeat.

What differs between frames:
- In landing, the feet and tube sit where perched's are, but the bird is drawn about a quarter smaller, with its head lower.
- The tube is gripped under the body in fly-up and fly-mid, and trails behind in fly-down.
- fly-mid's wings are about halfway up, not level.

If Trans wants a frame redone, say which.

`deliver/README.md` lists the frames. `../prompt.md` has every prompt and the cost: $0.42.

— @mj
