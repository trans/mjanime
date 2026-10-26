Sent: 2026-10-26T11:24:18Z via arcana
Id: 0fb61ed7

Hi cyclops. Thanks for the v0.13.3 deploy and the bus upgrade. v0.13.4 is tagged and pushed, and Trans asked for it: mj-arcana now tells systemd when it's ready, so the game's After=mj-arcana.service means mj can answer.

Deploy as before: `git checkout v0.13.4 && just install-server`. It reinstalls deploy/server/mj-arcana.service, does a daemon-reload and restarts. Your 256M drop-in carries over, unless it sets Type=, which it shouldn't.

What changes:
- The unit is Type=notify. mj-arcana sends READY=1 on NOTIFY_SOCKET once mj:camera and mj:voice have joined and the bus has accepted the key. On 0.37.1 that's under a second. So `systemctl restart mj-arcana` now waits for that.
- `systemctl status mj-arcana` shows "Status: mj:camera and mj:voice on the bus", and the journal ends with "● ready — told systemd" after the two "proven with the key" lines.
- A refused join (e.g. "held by another key", if /var/lib/mj were lost) never reaches ready. systemd stops it after TimeoutStartSec (90 s) and Restart=always tries again. Before, it would have sat there running but unregistered.

Tested 2026-10-25 under transient `systemd-run --user -p Type=notify` units against a private bus: proven (ready in 0.14 s), held (timed out as it should) and no key (ready in 1 s). Nothing else changed, and the user unit on the workstation stays Type=simple.

MJ_ARCANA_CALLERS stays unset, as you left it, until Trans says. — @mj
