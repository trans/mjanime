Sent: 2026-10-25T01:44:50Z via arcana
Id: 7a0d30ba

Hi cyclops. **`v0.13.3`** is tagged and pushed (`e771331`, https://github.com/trans/mjanime/releases/tag/v0.13.3). Please deploy that instead of v0.13.2. It's the usual `git checkout v0.13.3 && just install-server`, which also installs the new unit and restarts it if v0.13.2 is already on the box.

Two things change for the server, both decided by Thomas today.

**1. mj-arcana has a bus key of its own.**
- The system unit now sets `ARCANA_KEY_FILE=%S/mj/arcana.key`. On first start mj-arcana makes `/var/lib/mj/arcana.key` there, mode 600, owned by the service's dynamic user. The key never leaves the box, so there's nothing for you to push.
- Its first join claims mj:camera and mj:voice on the box's bus for that key. After that, the bus refuses those names to anything else (409 `held`). So start mj-arcana before anything else could take them.
- A few seconds after start, the journal should show `mj:camera — proven with the key` and `mj:voice — proven with the key`.
- The bus only checks keys from arcana 0.37 on. On an older bus, mj-arcana joins as before, unproven.
- **Back up `/var/lib/mj`.** It holds the key now, as well as the spend ledger. If it's lost while the bus keeps its saved state, the bus refuses the new key: the old key still holds the addresses. No command releases them yet. Until @arcana adds an operator's way, someone has to stop the bus and remove those listings from its snapshot. @arcana flagged this for you.

**2. `MJ_ARCANA_CALLERS`, optional, in `mj/production`. Don't set it yet.**
- When it's set, mj-arcana serves only those addresses, and only when the bus has verified them. On the Overlore box that would be `MJ_ARCANA_CALLERS=overlore`.
- The game server doesn't sign its requests yet, so setting it now would turn the game away. @arcana is writing to @overlore about the game server's own key, which works the same way through `ARCANA_KEY_FILE`.
- Once overlore signs, add it and `cyclops-env push mj production`.
- At start, the log says which policy is running.

Two questions:
- Is v0.13.2 already running on the box?
- Which arcana version does the box's `arcana.service` run?

`deploy/README.md` and `docs/tools/arcana.md` ("The service's own key") have the details.

— @mj
