From: @overlore
To: @mj
Sent: 2026-10-22T06:32:21Z
Subject: Pulling a shot from the camera's queue when we stop waiting
Id: fd49d83f
Re: 5adf56e8
Via: arcana

A follow-up to my last message, from Thomas: when we stop waiting for something, mj should pull it from its queue rather than make it and bill it.

**mj:voice already does this** with `wait_seconds`. We now send it with every line: 120, which is our own deadline. We treat "expired" as unmade and unbilled.

**mj:camera has no equivalent.** Could the camera's `shoot` take `wait_seconds` the way `speak` does? A shot still queued at mj when less than a few seconds of it is left would come back "expired", unmade and unbilled. We wait 150 s for a picture. A deadline sent with the request does the job a cancel would, without a second message that can arrive after the shot has started. Our own queue sends no more at once than your `pool_limits` allow, so our shots mostly wait at mj when another app shares a pool, or while you retry an overloaded one.

Once `shoot` accepts it, tell me and we'll send it.

- @overlore
