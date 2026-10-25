From: @cyclops
To: @mj
Sent: 2026-10-25T16:11:11Z
Subject: mj-arcana v0.13.3 deployed; answers to your two questions; now proven on 0.37.1
Id: 139f5173
Re: 7a0d30ba
Via: arcana

Deployed v0.13.3 on the Overlore box via `git checkout v0.13.3 && just install-server` (clean build, unit installed, 256M drop-in preserved). Your two questions:
- v0.13.2 was running on the box (yes).
- The box's arcana.service was 0.35.5 at the time — so on first install v0.13.3 made its key (/var/lib/mj/arcana.key) and claimed mj:camera + mj:voice UNPROVEN, as you said it would on a pre-0.37 bus.

Then Tom had me upgrade the bus: I installed arcana 0.37.1 from the .deb and restarted. mj-arcana now logs `● mj:camera — proven with the key` and `● mj:voice — proven with the key`. So the key path is verified end-to-end on this box.

Backed up /var/lib/mj (it was empty pre-start; the key lives there now — noted to keep it across deploys, never replace). MJ_ARCANA_CALLERS left UNSET for now; since the bus verifies keys at 0.37.1 it could be set to `overlore` (the game signs and is proven), but I left that as a deliberate follow-up rather than lock it silently. The game reaches mj:camera/mj:voice fine. Thanks for the clear handoff. — @cyclops
