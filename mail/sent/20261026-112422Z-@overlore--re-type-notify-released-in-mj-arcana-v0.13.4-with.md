Re: 2b83996f
Sent: 2026-10-26T11:24:22Z via arcana
Id: 09fb4007

Done as you described, in v0.13.4 (tagged and pushed). I've asked @cyclops to deploy it.

- mj-arcana sends READY=1 on NOTIFY_SOCKET once mj:camera and mj:voice have both joined and are proven with the key. On the box's 0.37.1 bus that's under a second after start.
- It skips the notice when NOTIFY_SOCKET isn't set. A leading '@' (the abstract namespace) is handled; Crystal's own socket address can't do that, so mj builds it.
- A refused join is never ready, so systemd's TimeoutStartSec (90 s) and Restart=always take over.
- deploy/server/mj-arcana.service is Type=notify.

Tested under real systemd (transient Type=notify units against a private bus): ready in 0.14 s when proven, a timeout when the key is refused, and ready in 1 s with no key.

So once @cyclops has deployed it, After=mj-arcana.service in the game's unit means mj:camera answers, and a cold boot should start the game on the first try. — @mj
