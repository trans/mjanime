# deploy/

Running mj's long-lived pieces as systemd **user** services, matching the convention the
other Silicon Circus services use (`curio`, `camelot`): user units under
`~/.config/systemd/user`, hardened, with every path stated explicitly.

| unit | what it is |
| --- | --- |
| [`mj-arcana.service`](mj-arcana.service) | `mj:camera` and `mj:voice` on the Arcana bus — see [docs/tools/arcana.md](../docs/tools/arcana.md) |

`mj bus` (the prop/pixelize/base/decorate/sfx engines) and `mj serve` (the web UI on port
21683) have no unit yet; ask if you want them.

## Install

```sh
just install-service      # builds, writes the env file, installs, enables, starts
just logs                 # journalctl -f
just uninstall-service    # leaves ~/.config/mj/env alone — it holds your keys
```

`install-service` substitutes the checkout path into the unit, so the shipped file carries
`@MJ_DIR@` rather than one machine's layout and this works from any clone.

## ⚠️ The unit cannot read `.env`

**`.env` is bash.** Its lines are `export RUNWARE_API_KEY=…`, and systemd's
`EnvironmentFile=` does not understand `export`. It logs

```
Ignoring invalid environment assignment 'export RUNWARE_API_KEY=…'
```

and continues with the variable **unset**. Verified, not assumed: a probe unit reading a
file with both forms saw the plain `BAZ` and reported `FOO=[UNSET]`.

That failure is quiet and particularly nasty here, because **both services are key-gated.**
With no keys `mj-arcana` starts, reports itself healthy, logs cheerfully — and registers
*nothing*. `systemctl status` shows `active (running)` while the bus directory has no
`mj:camera` and no `mj:voice`. Exactly the shape of the `Toolset#start` trap: a service
that runs and is invisible.

So `just systemd-env` translates `.env` into `~/.config/mj/env`, stripping `export` and
keeping only `KEY=value` lines, at mode 600 and outside the repo. Re-run it after changing
a key, then `systemctl --user restart mj-arcana`.

`EnvironmentFile=` is deliberately **not** prefixed with `-`: a missing env file should
fail loudly rather than start a service that can do nothing.

## What the sandbox allows, and why

`ProtectSystem=strict` plus `ProtectHome=read-only`, so the writable set is stated rather
than inherited:

- **`%h/.local/share/mj`** — every billed call appends to `spend.jsonl`. Omit this and
  generation fails *after* the provider has already charged you.
- **`%h/.config/GIMP`, `%h/.cache/GIMP`** (`-` prefixed, so absence is fine) — `format:
  "xcf"` shells out to `gimp-console`, which insists on writing its own config.
- **`PrivateTmp=true`** covers the short-lived scratch files: GIMP's conversion dir, and
  the probe file `ffprobe` measures audio duration from.

Verified under the running sandbox: both services register, a billed `shoot` succeeds and
lands in the ledger, `speak` returns a measured duration, and `format: "xcf"` converts.

**`output_path` is restricted by this, by design.** A caller asking `shoot` or `speak` to
write into the home directory gets a permission error — bus services are
filesystem-isolated and base64 is the portable answer. If you want a drop directory, add it
to the unit explicitly:

```ini
ReadWritePaths=%h/Pictures/Intake
```

## The bus is not a dependency

`arcana` is deliberately absent from `After=`/`Requires=`: it is not a user unit on every
host, and the service does not need it at boot. If the bus is down the connect fails, the
unit restarts, and it joins whenever the bus appears. `Restart=always` with `RestartSec=2`
is the entire retry policy.
