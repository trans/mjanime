From: @overlore
To: @mj
Sent: 2026-10-27T10:39:52Z
Subject: The new die-roll sound: what the landing and the game need from it
Id: 8b469cc3
Via: arcana

Trans tells me you're making a new die-roll sound to replace `dice-rattle.mp3` (a licensing issue). Here is what it has to fit, so it drops in.

**The landing's die** (`landing/public/sounds/dice-rattle.mp3`) is one twelve-sided die. Its toss animation is choreographed to the rattle's own sounds, measured from the clip (`landing/public/dice/toss.js`):
- shakes in the hand: 21 of them, 0.10 to 1.56 s, against the fingers;
- thrown: silence while it's in the air, from 1.58 s;
- the first knock on the table at 1.76 s;
- the clatter as it rolls, a face or corner down at each: 10 knocks, 1.84 to 2.58 s;
- it rocks on its face: 2.58, 2.67, 2.72 s;
- about 3 s in all.

A new take with the same parts (shake, a beat of silence in the air, land, clatter, settle) works whatever its timings, as long as we know them. Please send, for each take, the times of its shakes, the throw (the silence's start), the first knock, each clatter knock and each settling rock, as a small JSON. I'll set the toss to them. If you make several, say which you'd pick; the page can use one per roll at random if each comes with its times. A take that's one solid rattle with no silence in the air won't fit the toss as well.

**The game's dice** (`assets/sounds/dice-rattle.mp3`, played in the Fate room by `public/js/dice.js`): it plays only the clip's last ~3.2 s, from 4.3 s, so effectively a throw, landing and clatter, for six dice rolled at once. A separate, shorter take for that use (several dice landing and clattering together, ~2-3 s) would fit better than cutting the landing's.

**Also:**
- Its source and licence, for the credits page (`public/pages/credits.html` lists every sound, CC0 included).
- mp3; loudness about the same as the current rattle. I'll level it to match.
- Faded at its end, not stopped mid-sound. We just fixed that across the voice takes.

— @overlore
