Re: 5bff40f0
Sent: 2026-10-22T14:58:22Z via arcana
Id: 764bb4e3

Done: a system unit, `deploy/server/mj-arcana.service`, in **v0.13.1** (`bad0e9e`, https://github.com/trans/mjanime/releases/tag/v0.13.1). mj-arcana's code is unchanged from v0.13.0. Only the unit, `just install-server` and the docs are new.

- **User:** `DynamicUser=yes`.
- **Data:** `StateDirectory=mj`, so `/var/lib/mj` holds the ledger (`spend.jsonl`) and `out/`, and it persists across restarts.
- **Keys:** `EnvironmentFile=/etc/mj/env`, root-owned, mode 600. systemd reads it before dropping to the service's user, so leave `--group` unset.
- **Binary:** `/usr/local/bin/mj-arcana`.
- **Limits:** `MemoryMax=1G` and `TasksMax=256` are already in the unit. mj-arcana peaked at 14 MB on the workstation. Tune either with a drop-in.

On the box, as root:

```sh
mkdir -m 700 /etc/mj    # the first push is written, then chmod'ed 600; a private directory covers that moment
```

From the workstation:

```sh
cyclops-env config mj production --host=root@<box> --key=<key> --path=/etc/mj/env --restart=mj-arcana
cyclops-env push mj production
```

Then on the box:

```sh
git clone https://github.com/trans/mjanime.git && cd mjanime && git checkout v0.13.1
just install-server
```

`just install-server` builds mj-arcana for release. It installs the binary and the unit, enables the unit and restarts it. It refuses to run without root, or without `/etc/mj/env` at mode 600. It warns if `ffprobe` is missing.

Packages: crystal, shards, git, just and ffmpeg. cmake isn't needed: the server build has no ONNX shim.

The bus defaults to `ws://localhost:19118/bus`. If it's elsewhere, add `ARCANA_WS_URL` to `mj/production`. mj-arcana uses no bus token.

The unit hasn't run as a system unit yet, since that needs root here. `systemd-analyze verify` passes it, and `security` scores it 1.5. On the first start, check three things:
- both `mj:camera` and `mj:voice` show in the bus directory;
- `journalctl -u mj-arcana` is clean;
- a first call adds a row to `/var/lib/mj/spend.jsonl`.

`output_path` files land in `/var/lib/mj/out`, which is private to the service's user. Another program on the box can't read them, so take the base64 replies.

— @mj
