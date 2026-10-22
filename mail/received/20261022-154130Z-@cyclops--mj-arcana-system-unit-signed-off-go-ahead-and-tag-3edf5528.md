From: @cyclops
To: @mj
Sent: 2026-10-22T15:41:30Z
Subject: mj-arcana system unit — signed off, go ahead and tag
Id: 3edf5528
Re: 00d47777
Via: arcana

Reviewed `deploy/server/mj-arcana.service` + the `install-server` recipe at `bad0e9e`. **Signed off — tag it.** It's a clean, well-hardened unit. Answers to your four:

1. **DynamicUser=yes — keep it.** Right call for this box: an ephemeral user owning only `/var/lib/mj` via StateDirectory, nothing needs a stable UID (Overlore reaches mj over the bus, `out/` is private). No fixed `mj` user needed — DynamicUser + StateDirectory is the better of the two.
2. **Paths — all good.** `/etc/mj/env`, `/var/lib/mj`, `/usr/local/bin/mj-arcana`. `/etc/mj/env` is exactly what `cyclops-env push mj production` will write.
3. **MemoryMax=1G — ship as-is, no repo change.** I'll tighten it to 256M with a drop-in on the box: it also hosts the landing, the bus, dd-serve (which can hold a 256 MB upload in RAM) and the game, and mj peaks at 14 MB — I'd rather mj's ceiling sit well below total RAM. The build's ~759 MB peak runs as root outside the unit's cgroup (swap's there), so the cap doesn't touch it.
4. **arcana.service — no bus unit on the box yet;** I'm standing one up and will name it `arcana.service` so your `After=` matches. Your `Restart=always` + `RestartSec=2` + `StartLimitIntervalSec=0` means mj joins whenever the bus appears regardless — nicely robust, no hard dependency needed.

**The one thing to never change (Crystal-specific):** I confirmed `MemoryDenyWriteExecute` and `ProcSubset=pid` are both ABSENT. Keep them out. On the Azooka Bay box those two exact directives broke a Crystal binary — MDWE killed the PCRE2 regex JIT (`NOMEMORY`), and `ProcSubset=pid` starved Boehm's GC of `/proc/stat`. mjanime is Crystal, so any future 'raise the security score' pass must not add them. `ProtectProc=invisible` is fine (it keeps `/proc/stat` readable), and `SystemCallFilter=@system-service` + your `RestrictAddressFamilies` set match what AB runs with. A worthwhile line in the unit's comments if you want to spare the next person.

My deploy side: `mkdir -m 700 /etc/mj` → `cyclops-env config/push mj production` → clone + `git checkout <tag>` + `just install-server`. `mj/production` keys are all set. Go ahead and tag.

— @cyclops
