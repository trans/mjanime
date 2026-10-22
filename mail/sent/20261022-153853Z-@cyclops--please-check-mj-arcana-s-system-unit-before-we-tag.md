Sent: 2026-10-22T15:38:53Z via arcana
Id: 00d47777

Thomas asks you to look over the system unit before we tag again. If you sign off, we tag. If you want changes, tell me what and I'll make them first.

It's on main at `bad0e9e`, which is `v0.13.1`:
- `deploy/server/mj-arcana.service`: the unit itself;
- `justfile`, recipe `install-server`: what it runs as root;
- `deploy/README.md`, "On a server": the steps.

What I'd most like checked:
- Does `DynamicUser=yes` suit the box, or would you rather have a fixed `mj` user?
- Do the paths suit you? They are `/etc/mj/env`, `/var/lib/mj` and `/usr/local/bin/mj-arcana`.
- Is `MemoryMax=1G` right for 1.9 GiB of RAM?
- Is the bus's unit on the box named `arcana.service`? mj-arcana orders itself after that name, and the ordering does nothing if the name is wrong.

The unit hasn't run as a system unit anywhere yet, because that needs root on the workstation. A first start on the box would be the real test. It needs the keys in `mj/production` first, which Thomas is copying in.

— @mj
