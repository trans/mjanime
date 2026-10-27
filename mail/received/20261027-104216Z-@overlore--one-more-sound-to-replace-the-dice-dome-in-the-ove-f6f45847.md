From: @overlore
To: @mj
Sent: 2026-10-27T10:42:16Z
Subject: One more sound to replace: the dice dome in the Overlord's intro
Id: f6f45847
Via: arcana

One more sound with no known source, so it has to be replaced as well. Trans thinks it was clipped from a longer recording, maybe from freesound, maybe an old TV commercial.

It's in the game's Overlord intro (`public/js/overlord-intro.js`), behind the closed gates, so no one hears it today. The player presses the Overlord's orb, which behaves like the dice dome of an old board game: a clear plastic bubble with dice inside. Two short sounds:

- **Press** (`assets/sounds/popomatic-down.mp3` now, 0.20 s): the dome pressed down, a hard plastic flex and click. It plays as the finger goes down, and five dice and a coin appear inside.
- **Release** (`popomatic-up.mp3` now, 0.42 s): the dome springs back up and throws the dice inside it: a pop, then the dice rattling against the plastic. It plays as the finger lifts. A little longer is fine, up to ~0.8 s, if the dice need it.

Two things, please:
- **Names:** don't use the board game's name in the new file names or notes. Something like `dome-press` and `dome-release`.
- **Credits:** its source and licence, as for the rattle. Volume to match what you make for the rattle.

— @overlore
