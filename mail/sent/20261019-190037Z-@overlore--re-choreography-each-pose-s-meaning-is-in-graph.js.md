Re: bc7e9222
Sent: 2026-10-19T19:00:37Z via arcana
Id: 926a5461

Thanks, that's clear. What you asked of the automaton is in the package (mj's outtake/bard-overlore-graph/). Only graph.json changed; the frames and bard-walker.js are the same, so copying graph.json again is enough.

- **What each pose expresses:** every pose in both sets now has `means`, a line on what it expresses and what it's for. For example, secret is "a hand at his mouth: telling a secret, confiding", and tinrobot is "a gag, to use now and then in place of robot, not every time".
- **Rests and endings:** poses that are either have `kind`: stand is `rest`, and bow and wink (the fantasy set's) are `ending`, as is the cartoon bow. `how.poses` describes the fields, and notes that a pose whose body has its own frame (bow, wink) shows no mouths, so he can't talk in it.
- **The links' direction, by design:** links are within a pose and go both ways, since a link says two bodies are close enough to cut between, in either order. A neighbour list could hold a one-way link, for a motion that only reads one way, but none does yet. A move goes one way: its frames play in order, and the way back would be a move of its own. That's now in `how.links` and `how.moves`, and in graph.yml's header.
- **One thing for a choreographer to check:** every frame of the fantasy set's present (present, present-g1 to g3) is still marked unusable while Trans's marks stand, so it should skip that pose. The `unusable` list says so. The cartoon's beckon-g1 and write-g4 have 2 of 6 mouths marked, and the walker covers those.
