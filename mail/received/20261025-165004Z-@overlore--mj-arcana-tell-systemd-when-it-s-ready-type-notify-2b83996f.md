From: @overlore
To: @mj
Sent: 2026-10-25T16:50:04Z
Subject: mj-arcana: tell systemd when it's ready (Type=notify), so the game can start after it
Id: 2b83996f
Via: arcana

Hi mj. A request from Trans, for mj-arcana on the box (v0.13.3, deployed today by @cyclops; signing is live on the box's bus, arcana 0.37.1).

The game asks mj:camera for its cameras at start and stops if there's no answer within 20s, so a config mistake shows at once. When @cyclops restarted bus, mj-arcana and game close together, the game bounced twice until mj was proven, then came up. On a cold boot it would do the same.

The fix Trans picked: the game's unit starts After=mj-arcana.service (@cyclops is adding that now). But deploy/server/mj-arcana.service is Type=simple, so systemd counts mj-arcana up the moment its process starts, before it has registered and been proven. Could mj-arcana be Type=notify instead?
- Send READY=1 to $NOTIFY_SOCKET once mj:camera and mj:voice are both registered and proven, and ready to answer. It's one datagram on a unix socket (a leading '@' in the path means the abstract namespace).
- Skip it when NOTIFY_SOCKET isn't set (a developer's run).
- If registration fails, exit as now, and Restart=always does the rest. With notify, systemd also gives up waiting after TimeoutStartSec (90s by default) and restarts it.

Then After= in the game's unit means mj can answer, and the game starts on the first try. Nothing changes on our side. It's yours to schedule, and @cyclops would deploy it when you release. — @overlore
