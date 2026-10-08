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
just uninstall-service    # leaves your keys and project overrides in place
```

`install-service` substitutes the checkout path into the unit, so the shipped file carries
`@MJ_DIR@` rather than one machine's layout and this works from any clone.

## Where the keys live

**One file, shared by every service that needs it: `~/.config/secrets/providers.conf`**,
mode 600 in a 700 directory, plain `KEY=value`. The unit names it with `EnvironmentFile=`.

```ini
ANTHROPIC_API_KEY=…
OPENAI_API_KEY=…
RUNWARE_API_KEY=…
GEMINI_API_KEY=…
```

Add a key, then just restart — `EnvironmentFile` is re-read at each unit start, so there is
no `daemon-reexec` dance:

```sh
systemctl --user restart mj-arcana
just keys
```

### Why not `~/.config/environment.d/`

It is the obvious answer and it is too broad. The systemd *user manager* passes that
environment to **every** user unit, so provider keys land in processes that have no
business holding them. Measured on this host, before the cleanup, `OPENAI_API_KEY` and
`ANTHROPIC_API_KEY` were in the environment of roughly **sixty** processes: the whole GNOME
session, `pipewire`, bluetooth's `obexd`, the xdg desktop portals, `speech-dispatcher`,
`localsearch` (a file indexer), `gnome-software`. None of them consume an AI key.

`EnvironmentFile=` reaches only the units that ask for it, and keeps the keys out of
`systemctl --user show-environment` entirely.

If keys are already in the manager environment from an old
`systemctl --user import-environment`, removing a file does not clear them:

```sh
systemctl --user unset-environment ANTHROPIC_API_KEY OPENAI_API_KEY RUNWARE_API_KEY
```

That stops *new* units inheriting them; processes already running keep their copy until
restarted. Note that anything re-running `import-environment` will put them back.

### `just keys` — three columns, because they differ

```
KEY                      FILE     SERVICE   SHELL
ANTHROPIC_API_KEY        yes      yes       yes
RUNWARE_API_KEY          yes      yes       yes
GEMINI_API_KEY           -        -         -
```

**SERVICE** is read from the running process's own environment (`/proc/<pid>/environ`), so
it is ground truth rather than an inference about what the unit *should* see.

### Three ways a key that "is set" is invisible to the service

All verified here, and all failing in the same quiet shape.

1. **A bash `.env` cannot be an `EnvironmentFile`.** Its lines are `export KEY=value`;
   systemd logs `Ignoring invalid environment assignment` and leaves the variable **unset**.
   A probe unit reading a file with both forms saw the plain assignment and reported the
   exported one as `UNSET`.
2. **fish universal variables (`set -Ux`) never reach systemd.** They live in
   `~/.config/fish/fish_variables` and reach your *shell* only.
3. **`environment.d` added after the manager started** is absent until
   `systemctl --user daemon-reexec`.

Why this bites harder than it looks: **both mj services are key-gated.** Missing *all* keys
exits non-zero and is obvious; missing *one* leaves the other running, so `systemctl status`
reads `active (running)` while `mj:camera` is quietly absent from the bus directory.
`just install-service` therefore prints the key table and shouts if `RUNWARE_API_KEY` is not
visible.

### The shell reads the same file

`~/.config/fish/conf.d/provider-keys.fish` loads that one file, so the shell and the
services never disagree:

```fish
set -l __keyfile ~/.config/secrets/providers.conf
if test -r $__keyfile
    for __line in (cat $__keyfile)
        string match -qr '^\s*(#|$)' -- $__line; and continue
        set -gx (string split -m1 = -- $__line)
    end
end
```

Keep no `set -Ux` copies — a universal shadows the file and you are back to two things to
rotate. Erase them with `set -Ue ANTHROPIC_API_KEY`. Beware when checking:
`fish --no-config` still **inherits the parent environment**, so it does not prove a key
came from a universal. Scrub first:

```sh
env -u ANTHROPIC_API_KEY fish --no-config -c 'echo $ANTHROPIC_API_KEY'
```

`fish_variables` is created world-readable (`0644`) — worth a `chmod 600` whatever else you
store in it.

### Stricter, if you want it

`EnvironmentFile` still puts secrets in the process environment, visible via
`/proc/<pid>/environ` to the same user. systemd's `LoadCredential=` / `ImportCredential=`
passes a secret to one named unit without it appearing in the environment at all. That
needs the program to read `$CREDENTIALS_DIRECTORY`, so it is a code change, not just a unit
change — noted rather than done.

### `~/.config/mj/env` is not for keys

`just systemd-env` writes only `MJ_*` variables there — project-local tuning
(`MJ_RUNWARE_RETRIES`, `MJ_RUNWARE_READ_TIMEOUT`, `MJ_OPENAI_TTS_USD_PER_MINUTE`,
`MJ_ELEVENLABS_USD_PER_1K_CHARS`). That `EnvironmentFile=` is `-` prefixed and optional.

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
