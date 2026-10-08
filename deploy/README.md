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

## Where the keys live

**One place, machine-wide: `~/.config/environment.d/*.conf`.** The systemd *user manager*
reads those at startup and every user unit inherits them, so provider credentials are not
copied per project and not rotated in N places.

```ini
# ~/.config/environment.d/50-provider-keys.conf   (mode 600)
ANTHROPIC_API_KEY=…
OPENAI_API_KEY=…
RUNWARE_API_KEY=…
GEMINI_API_KEY=…
```

After editing, the manager must re-read it. No logout needed:

```sh
systemctl --user daemon-reexec          # manager re-reads environment.d; units keep running
systemctl --user restart mj-arcana      # the unit picks up the new value
just keys                               # confirm
```

`just keys` exists because this is confusing in a specific way:

```
KEY                      SYSTEMD    SHELL
ANTHROPIC_API_KEY        yes        yes
OPENAI_API_KEY           yes        yes
RUNWARE_API_KEY          yes        -
GEMINI_API_KEY           -          -
```

The **SYSTEMD** column is what the service sees. The two columns are genuinely independent,
and a key can be in either without the other.

### Two ways a key that "is set" is invisible to systemd

Both verified here, not assumed — and both fail in the same quiet shape.

1. **A bash `.env` cannot be an `EnvironmentFile`.** Its lines are `export KEY=value`, and
   systemd logs `Ignoring invalid environment assignment 'export KEY=…'` and continues with
   the variable **unset**. A probe unit reading a file with both forms saw the plain
   assignment and reported the exported one as `UNSET`.
2. **fish universal variables (`set -Ux`) are invisible to systemd.** They live in
   `~/.config/fish/fish_variables` and reach your *shell*, not the user manager. If keys
   appear in the manager environment at all it is because something once ran
   `systemctl --user import-environment` — a snapshot, so a key added later is simply
   absent. That is exactly why `RUNWARE_API_KEY` was missing here while `ANTHROPIC` and
   `OPENAI` were present.

Why it matters more than it looks: **both mj services are key-gated.** Missing *all* keys
exits non-zero and is obvious, but a missing *one* leaves the other running — so
`systemctl status` reads `active (running)` while `mj:camera` is quietly absent from the bus
directory. `just install-service` therefore prints the key table and shouts if
`RUNWARE_API_KEY` is not visible.

### Keeping fish and systemd in step

`environment.d` is the canonical store; have fish read it rather than holding its own copy,
so there is one file to rotate. In `~/.config/fish/conf.d/provider-keys.fish`:

```fish
for line in (string match -rv '^\s*(#|$)' < ~/.config/environment.d/50-provider-keys.conf)
    set -gx (string split -m1 = $line)
end
```

Then remove the duplicates with `set -Ue ANTHROPIC_API_KEY` (and so on), or they will shadow
the file and you will be back to two sources.

### `~/.config/mj/env` is not for keys

`just systemd-env` writes only `MJ_*` variables there — project-local tuning
(`MJ_RUNWARE_RETRIES`, `MJ_RUNWARE_READ_TIMEOUT`, `MJ_OPENAI_TTS_USD_PER_MINUTE`,
`MJ_ELEVENLABS_USD_PER_1K_CHARS`). The unit's `EnvironmentFile=` is `-` prefixed, so it is
optional.

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
