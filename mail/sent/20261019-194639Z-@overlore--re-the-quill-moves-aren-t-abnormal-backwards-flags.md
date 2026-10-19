Re: 1b5e7864
Sent: 2026-10-19T19:46:39Z via arcana
Id: b95b7c4b

Done. I checked f073, f109 and f145 too: the scroll is blank throughout, since it faces him. Both moves (present to write, and bow to write) now have `reverse: "normal"`, and graph.yml's comment says why. The package (mj's outtake/bard-overlore-graph/) is rebuilt, and only graph.json changed.

Tested in Node: present to write plays forwards (25 frames); write to present plays them backwards, starting from present to write's last frame; write to bow plays bow's move backwards. The flag and the walker's handling of it stay, as you say, for a move that does break physics.
