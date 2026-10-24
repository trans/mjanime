# deploy/

Running mj's long-lived pieces as systemd services. On the workstation they are **user**
units, matching the convention the other Silicon Circus services use (`curio`, `camelot`):
under `~/.config/systemd/user`, hardened, with every path stated explicitly. On a server,
where every service is a system unit, mj-arcana is one too ([On a server](#on-a-server)).

| unit | what it is |
| --- | --- |
| [`mj-arcana.service`](mj-arcana.service) | `mj:camera` and `mj:voice` on the Arcana bus — see [docs/tools/arcana.md](../docs/tools/arcana.md) |
| [`server/mj-arcana.service`](server/mj-arcana.service) | the same, as a system unit for a server ([On a server](#on-a-server)) |

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

## On a server

`install-service` is for the workstation: it builds all of mj, the ONNX shim included, and
pulls the `local` keys from the cyclops store on this machine. A server uses
`just install-server`, from its own checkout, which builds only mj-arcana and installs it as
a **system** unit, [`server/mj-arcana.service`](server/mj-arcana.service), taking its keys
from a file cyclops pushes.

| | workstation (user unit) | server (system unit) |
| --- | --- | --- |
| runs as | you | a dynamic user, made when it starts |
| binary | `<checkout>/bin/mj-arcana` | `/usr/local/bin/mj-arcana` |
| keys | `~/.config/mj/env` | `/etc/mj/env`, root, mode 600 |
| ledger, `out/` | `~/.local/share/mj` | `/var/lib/mj` |

1. **Packages:** Crystal, shards and git; just; ffmpeg, whose `ffprobe` measures each spoken
   line (and prices OpenAI speech that comes back without usage); GIMP only for
   `format: "xcf"`. No cmake or ONNX Runtime: the server build has no shim. A cold release
   build of mj-arcana peaked at 759 MB and took 18 s here (2026-10-22), so a 1 GB droplet
   needs swap.
2. **Keys, from the workstation.** `mj/production` must hold every key the server is to use:
   without `RUNWARE_API_KEY`, mj:camera doesn't start. Make the directory on the server
   private (`mkdir -m 700 /etc/mj`): cyclops writes the file, then sets it to mode 600, so a
   first push is readable for that moment unless its directory isn't. Set the push target
   once, and push:

   ```sh
   cyclops-env config mj production --host=root@<droplet> --key=~/.ssh/<key> \
     --path=/etc/mj/env --restart=mj-arcana
   cyclops-env push mj production       # writes the file, mode 600
   ```

   If the bus isn't at `ws://localhost:19118/bus`, add `ARCANA_WS_URL` to the scope.
   Add `MJ_ARCANA_CALLERS` too, naming the box's own callers (`overlore` on the Overlore
   box): with it, only those addresses are served, and only when the bus verified them, so
   set it once they sign ([Callers](../docs/tools/arcana.md#callers-anyone-here-a-list-on-a-deployment)).
   Without it, anything on the box may spend the keys.
3. **On the server**, as root:

   ```sh
   git clone https://github.com/trans/mjanime.git && cd mjanime && git checkout v<version>
   just install-server
   ```

   It refuses to start without the key file, and warns if ffprobe is missing.
4. **Later:** a new release is `git checkout v<version> && just install-server`; new keys are
   `cyclops-env push mj production`, which restarts the unit.

The service's own bus key is made on first start at `/var/lib/mj/arcana.key` (the unit sets
`ARCANA_KEY_FILE`) and never leaves the box. Its first join claims mj:camera and mj:voice on
the box's bus. Back it up with `/var/lib/mj`: if that directory is lost while the bus keeps
its state, the bus refuses the new key until the old listings are removed by hand
([The service's own key](../docs/tools/arcana.md#the-services-own-key)).

The system unit keeps the user unit's hardening, less what has no meaning there (the home
and runtime directories), plus an empty capability set and other processes hidden:
`systemd-analyze security` scores it 1.5 (2026-10-22, offline). It has not run as a system
unit yet, since that needs root here; `format: "xcf"` under it is untested. `output_path`
writes under `/var/lib/mj/out`, private to the service's user, so a caller on the same box
can't read the file there; take the base64 reply instead.

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

Any bus participant can send the service a request, so it is held to what it needs (the
security review, 2026-10-21). `systemd-analyze --user security mj-arcana` scored it 8.0
("exposed") before and 3.7 after.

**The home directory is an empty tmpfs** (`ProtectHome=tmpfs`), with three things bound back:

- **`@MJ_DIR@/bin`, read-only**: the binary, and nothing else of the checkout, so neither its
  `.env` nor `.ai/arcana.token` is in reach. The working directory is `~/.local/share/mj`.
- **`%h/.local/share/mj`**: every billed call appends to `spend.jsonl`, and `output_path`
  writes under `mj/out`. Omit this and generation fails *after* the provider has already
  charged you.
- **`%h/.config/GIMP`, `%h/.cache/GIMP`** (`-` prefixed, so absence is fine): `format:
  "xcf"` shells out to `gimp-console`, which insists on writing its own config.

`ProtectHome=read-only`, the earlier setting, left every file the user can read readable:
`~/.ssh`, `~/.config/mj/env` and cyclops' store. Checked from inside the running service
(2026-10-22): those, the checkout's `.env` and the user's runtime directory are hidden.

**The user's runtime directory is hidden** (`InaccessiblePaths=-%t`). It holds the session bus
and the user manager's socket, through which a compromised process could ask systemd to start
an unsandboxed one.

**The rest:**
- devices, kernel settings, clock and hostname are off limits;
- no new namespaces, realtime scheduling or SUID;
- sockets for IP, Unix and netlink only;
- system calls limited to `@system-service`, with others failing as EPERM;
- files created private (`UMask=0077`);
- `MemoryMax=2G` and `TasksMax=256`, so a flood of queued requests takes the service down,
  not the machine.

**GIMP needs `@privileged`'s calls.** Excluding them as well (`~@privileged`) kills
`gimp-console`'s plug-ins with "Bad system call", so `format: "xcf"` fails after the shot is
billed. Tested setting by setting, 2026-10-22. Re-test `xcf` after any change here.

`PrivateTmp=true` covers the short-lived scratch files: GIMP's conversion dir, and the probe
file `ffprobe` measures audio duration from.

Verified under this sandbox (2026-10-22): both services register, a Flash line and an OpenAI
picture were made and written with `output_path`, a Runware shot with a public `reference_url`
converted to `xcf`, and every one is in the ledger.

**`output_path` is confined by the service itself**, whatever the unit allows: a new file
inside `~/.local/share/mj/out`, never over an existing one (`src/arcana/output_path.cr`).

## The bus is not a dependency

`arcana` is deliberately absent from `After=`/`Requires=`: it is not a user unit on every
host, and the service does not need it at boot. If the bus is down the connect fails, the
unit restarts, and it joins whenever the bus appears. `Restart=always` with `RestartSec=2`
is the entire retry policy.
