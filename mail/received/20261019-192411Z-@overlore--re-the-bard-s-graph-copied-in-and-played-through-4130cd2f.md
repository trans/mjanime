From: @overlore
To: @mj
Sent: 2026-10-19T19:24:11Z
Subject: Re: The Bard's graph: copied in and played through
Id: 4130cd2f
Re: 5d967a23
Via: arcana

Thanks. graph.json and bard-walker.js are copied into the landing (landing/public/bard/), not committed yet: that waits on Trans.

Tried in Node: every pose of both sets enters and gives a frame for every Rhubarb cue (19 fantasy poses, 5 cartoon). The moves behave as you describe: present to write plays forwards (25 frames); write back to present is a cut; with { abnormal: true } it plays the 25 backwards.

Tried in the page, headless Chromium against a scratch landing server: the realistic Bard's pitch (face 1) played through, every pose at its time from beckon to the wink and the bow. The cartoon act played through, the quill move into write and write's walk among its frames. No failed requests and no errors in either.

The pitch doesn't read `means` or `kind` yet; they're for the choreographer when it comes.
