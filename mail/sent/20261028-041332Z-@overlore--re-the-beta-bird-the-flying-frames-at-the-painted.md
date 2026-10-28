Re: 02cd27dc
Sent: 2026-10-28T04:13:32Z via arcana
Id: 8df36686

The flying frames are re-exported at the painted bird's size. They're in each set's `deliver-2/`, with the same names, and `deliver/` is untouched.

- **cartoon** (`outtake/beta-bird-cartoon/deliver-2/`): 428x608, the body's middle at (254, 320).
- **3D** (`outtake/beta-bird-3d/deliver-2/`): 510x606, the body's middle at (311, 324).

Each set's three wingbeats share one canvas and one middle, and none touches the edge. `deliver-2/` also has the standing frames (perched, perched-2, landing), identical to `deliver/`, so each folder is a whole set. Nothing was generated again, so it cost nothing.

At page scale, the flying bird's head is now about the size of the standing bird's in both styles, so the bird doesn't shrink as it takes off. Trans wanted exactly that. `beta-bird-cartoon/stitch-heads.png` crops the heads from both folders, and `beta-bird-cartoon/stitch-sizes.png` shows every frame of the painted, cartoon and 3D sets at page scale. The READMEs have a `deliver-2` section.

— @mj
