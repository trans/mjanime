Sent: 2026-10-22T06:53:31Z via arcana
Id: d4402805

mjanime v0.13.0 is ready for the game's server: tag `v0.13.0`, commit `ced768c`, https://github.com/trans/mjanime (public). Thomas asked me to send you what you need to deploy it. Only mj-arcana runs there: the `mj:camera` and `mj:voice` services on the Arcana bus, which Overlore calls. The `mj` CLI and web UI stay on the workstation. The detail is in the repo's `deploy/README.md`, "On a server".

**Install.** From a checkout at the tag, as the user that will run it: `just install-server`. It builds only mj-arcana, in release mode (no ONNX shim, no web UI). It writes the systemd **user** unit to `~/.config/systemd/user/mj-arcana.service` with the checkout's path filled in, then enables and restarts it and shows its status.

- **Packages:** Crystal 1.19.1 or later (built here with 1.22.0), shards, just, and ffmpeg (its `ffprobe` measures each spoken line). GIMP only for xcf, which the game doesn't use.
- **Shards** come from public GitHub repos, pinned by `shard.lock` (arcana-core 0.18.0, arcana-ai 0.6.1).
- **Memory:** a cold build peaked at 759 MB and took 18 s here, so a 1 GB box needs swap.
- **Lingering** must be on for that user (`loginctl enable-linger <user>`), or the service stops at logout. The recipe warns if it's off.

**Environment.** The unit reads `EnvironmentFile=%h/.config/mj/env`: systemd format, mode 600. The recipe refuses to start without it. `mj/production` holds only `ELEVENLABS_API_KEY` today. It also needs:

- `RUNWARE_API_KEY`: without it mj:camera doesn't register at all;
- `OPENAI_API_KEY`: Overlore's narrators still use OpenAI's voices, and the OpenAI cameras use it;
- `GEMINI_API_KEY`: the Google cameras.

Thomas hasn't said whether production reuses `mj/local`'s keys or gets its own, so please ask him. Add `ARCANA_WS_URL` only if the bus isn't at `ws://localhost:19118/bus`.

No push target is configured for `mj/production` yet. Leave `--restart` unset: push runs `systemctl restart`, which doesn't reach a user unit. Restart it as the user instead, with `systemctl --user restart mj-arcana`. If you'd rather it be a system unit with its own user, like the box's other services, say so and mj will ship one.

**Checking it's up.** `journalctl --user -u mj-arcana` should show `mj:camera — 12 cameras` and `mj:voice — openai, elevenlabs; ElevenLabs <plan>: N at once`. The SERVICE column of `just keys`, run in the checkout, shows which keys reached the running process. The service writes only under `~/.local/share/mj`: `spend.jsonl`, the ledger of every paid call, and `out/` for `output_path`, which Overlore doesn't use.

**Later releases:** `git fetch --tags && git checkout v<version> && just install-server`. mj-arcana reads the ElevenLabs plan only at start, so restart it after Thomas upgrades to Pro, or it keeps Starter's limit of 3 lines at once.

- @mj
