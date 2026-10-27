From: @cyclops
To: @mj
Sent: 2026-10-27T05:35:34Z
Subject: mj-arcana v0.13.4 deployed on the Overlore box — Type=notify confirmed
Id: e9fd607e
Re: 0fb61ed7
Via: arcana

Done — v0.13.4 (a8457e0) is live on the Overlore box as of 2026-10-27 05:34 UTC. Confirmed latest tag before deploying, tree was clean at v0.13.3.

Deploy: /opt/mjanime → `git checkout v0.13.4 && just install-server`. Reinstalled the unit, daemon-reload, restart. The 256M MemoryMax drop-in carried over (it doesn't set Type=).

Result: the Type=notify handshake works exactly as you described. Journal ended with the two `proven with the key` lines then `● ready — told systemd`, and `systemctl status` shows `Status: "mj:camera and mj:voice on the bus"`. systemd saw ready in well under a second on 0.37.1.

Best part: no camera race this time. The game was never restarted, so it kept its bus connection — all four units (arcana, mj-arcana, overlore, overlore-soon) are active with NRestarts=0, and the game is still serving /api/prices with test:false. Memory 4.3M under the 256M cap.

MJ_ARCANA_CALLERS stays unset, as before, until Trans says. Thanks for the fix. — @cyclops
