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

## Where the keys live: the cyclops store

**Same mechanism as the cloud servers.** `cyclops-env` keeps secrets in an encrypted SQLite
store (`~/.config/cyclops/secrets.db`, AES-256-CBC, master key at 0600), scoped by
**service × environment**. It renders a systemd-format file; the unit reads it with
`EnvironmentFile=`. Locally the environment is `local`; on a droplet it is `production` and
cyclops pushes the file over ssh. One store, one CLI, one unit shape.

```sh
just env-pull                              # export mj/local -> ~/.config/mj/env, restart
cyclops-env set mj local KEY value         # change a value
cyclops-env export mj local                # see what would be written (systemd format)
just keys                                  # STORE / SERVICE / SHELL
```

`just keys` reads **SERVICE** from the running process's own `/proc/<pid>/environ`, so it is
ground truth rather than an inference about what the unit *ought* to see.

### Why this beats a shared plaintext file

Service × environment scoping is least privilege for free. mj's file holds exactly
`RUNWARE_API_KEY` and `OPENAI_API_KEY`. The shared-file arrangement that preceded it also
handed mj `ANTHROPIC_API_KEY`, which mj never uses — visible in `just keys` as
`ANTHROPIC_API_KEY  -  -  yes`: in your shell, and correctly absent from the service.

The scoping also handles a problem a flat file cannot. Across this machine's projects, five
variables hold **different values** — `OPENAI_API_KEY`, `STRIPE_SECRET_KEY`,
`STRIPE_WEBHOOK_SECRET`, `SUPABASE_JWT_SECRET`, `RESEND_API_KEY` — because `wow` and
`likely` have their own accounts. Flatten those into one file and a project silently starts
billing through another project's Stripe. Per-service scopes make that structurally
impossible.

### Three ways a key that "is set" is invisible to the service

All verified here, and all failing in the same quiet shape.

1. **A bash `.env` cannot be an `EnvironmentFile`.** Its lines are `export KEY=value`;
   systemd logs `Ignoring invalid environment assignment` and leaves the variable **unset**.
2. **fish universal variables (`set -Ux`) never reach systemd** — they are in
   `~/.config/fish/fish_variables` and reach your *shell* only. (That file is created
   `0644`, world-readable; worth a `chmod 600` whatever lives in it.)
3. **`~/.config/environment.d/` works but is far too broad.** The user manager passes it to
   *every* user unit: measured on this host, provider keys were in the environment of
   roughly **sixty** processes — the whole GNOME session, `pipewire`, bluetooth's `obexd`,
   the xdg portals, `localsearch`, `gnome-software`. Clear stale ones with
   `systemctl --user unset-environment KEY` (that stops *new* units inheriting; running
   processes keep their copy until restarted).

Why this bites harder than it looks: **both mj services are key-gated.** Missing *all* keys
exits non-zero and is obvious; missing *one* leaves the other running, so `systemctl status`
reads `active (running)` while `mj:camera` is quietly absent from the bus directory.

### Still open, for cyclops

- **`cyclops-env push` is ssh-only** (`config` requires `--host`), so local use needs the
  `export >` redirect that `just env-pull` does. A no-host target that writes locally and
  runs `systemctl --user restart` would make local and remote literally the same command.
- **Environment naming is inconsistent** in the existing store — `wow` has both `prod` and
  `production`, `onboard` has `_default`/`dev`/`production`, and `arcana` uses the
  environment slot for deploy targets (`likely`, `siliconcircus`). Worth settling before
  `local` becomes a standard everywhere.
- **Shells have no scope.** Services are per-project, but an interactive shell wants a
  general set; there is no `shared` concept. A `workstation` project scope would do it.
- **Stricter still:** `EnvironmentFile` leaves secrets in `/proc/<pid>/environ`.
  systemd's `LoadCredential=` avoids that, but needs the program to read
  `$CREDENTIALS_DIRECTORY` — a code change, noted rather than done.

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
