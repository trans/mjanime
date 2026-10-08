# Include dir for ONNX Runtime's C API header (the `mj matte --isnet` shim). Override if it moves.
ort_inc := "/usr/include/onnxruntime"

default:
    @just --list

# Install shard dependencies
deps:
    shards install

# Build the binary
build: deps shim
    mkdir -p bin
    crystal build src/mj.cr -o bin/mj

# Build the binary, do not update shards
compile: shim
    mkdir -p bin
    crystal build src/mj.cr -o bin/mj

# Build with optimizations
release: deps shim
    mkdir -p bin
    crystal build src/mj.cr -o bin/mj --release

# Run in development mode
run: deps shim
    crystal run src/mj.cr

# Compile the ONNX Runtime C shim (over the C API) for local matting (`mj matte --isnet`).
# The shim dlopen's libonnxruntime at runtime, so this links only -ldl — onnxruntime stays optional.
shim:
    cc -O2 -fPIC -c src/native/mjonnx.c -o src/native/mjonnx.o -I{{ort_inc}}

# Build and run `mj serve` in the foreground with .env loaded (Ctrl-C to stop)
serve: build
    sh -c '. ./.env; exec ./bin/mj serve'

# Kill any running mj, rebuild, and run `mj serve` in the foreground (Ctrl-C to stop)
restart: build
    -pkill -f '[b]in/mj serve' 2>/dev/null || true
    -pkill -f '[b]in/mj bus' 2>/dev/null || true
    sleep 1
    sh -c '. ./.env; exec ./bin/mj serve'

# Kill any running mj server (foreground or stray)
stop:
    -pkill -f '[b]in/mj serve' 2>/dev/null || true
    -pkill -f '[b]in/mj bus' 2>/dev/null || true
    @echo "stopped mj"

# Update shard dependencies to the latest allowed versions (e.g. after an arcana-core release)
update:
    shards update

# Type-check without generating code
check:
    crystal build src/mj.cr --no-codegen

# Run specs
test:
    crystal spec

# Clean build artifacts
clean:
    rm -rf bin lib .shards src/native/mjonnx.o

# --- deployment -----------------------------------------------------------------

# Where do mj's credentials actually reach? STORE is the encrypted cyclops store (the
# system of record, same as the cloud servers); SERVICE is the live environment of the
# running process, read from /proc, which is ground truth; SHELL is your interactive shell.
# A key set only in fish (`set -Ux`) shows up in SHELL alone and is invisible to the unit.
# Show which credentials reach the cyclops store, the running service, and your shell
keys:
    #!/usr/bin/env bash
    db=~/.config/cyclops/secrets.db
    pid=$(systemctl --user show -p MainPID --value mj-arcana.service 2>/dev/null)
    stored=$(sqlite3 "$db" "SELECT key FROM secrets WHERE project='mj' AND environment='local';" 2>/dev/null)
    printf '%-24s %-8s %-9s %-7s\n' KEY STORE SERVICE SHELL
    for k in ANTHROPIC_API_KEY OPENAI_API_KEY RUNWARE_API_KEY ELEVENLABS_API_KEY GEMINI_API_KEY GOOGLE_API_KEY; do
      st='-'; grep -qx "$k" <<< "$stored" && st=yes
      svc='-'
      if [ -n "$pid" ] && [ "$pid" != 0 ] && [ -r "/proc/$pid/environ" ]; then
        tr '\0' '\n' < "/proc/$pid/environ" | grep -q "^$k=" && svc=yes
      else
        svc='(down)'
      fi
      sh='-'; [ -n "${!k}" ] && sh=yes
      printf '%-24s %-8s %-9s %-7s\n' "$k" "$st" "$svc" "$sh"
    done
    echo ""
    echo "STORE = cyclops mj/local (encrypted). Change a value with:"
    echo "  cyclops-env set mj local KEY value   &&   just env-pull"

# Render mj's env from the cyclops store — the same mechanism the cloud servers use, so
# local and prod differ only in the environment name (`local` vs `production`) and in how
# the file is delivered (redirect here, ssh push there). Secrets live encrypted in
# ~/.config/cyclops/secrets.db, scoped service x environment.
# Pull mj's env from the cyclops store and restart the service
env-pull:
    @mkdir -p ~/.config/mj
    @~/Projects/cyclops/bin/cyclops-env export mj local --format=systemd > ~/.config/mj/env
    @chmod 600 ~/.config/mj/env
    @echo "wrote ~/.config/mj/env ($(grep -c . ~/.config/mj/env) vars) from cyclops mj/local"
    -@systemctl --user restart mj-arcana.service 2>/dev/null && echo "restarted mj-arcana"

# Install mj-arcana as a systemd user service, pointing at this checkout.
install-service: build env-pull
    @mkdir -p ~/.config/systemd/user
    @sed 's|@MJ_DIR@|{{justfile_directory()}}|g' deploy/mj-arcana.service > ~/.config/systemd/user/mj-arcana.service
    systemctl --user daemon-reload
    systemctl --user enable --now mj-arcana.service
    @sleep 2
    systemctl --user --no-pager --lines=0 status mj-arcana.service
    @echo ""
    @just keys
    @systemctl --user show-environment | grep -q '^RUNWARE_API_KEY=' || \
        echo "!! RUNWARE_API_KEY is not visible to systemd, so mj:camera did NOT register." 

# Remove the service (leaves keys in environment.d and ~/.config/mj/env untouched).
uninstall-service:
    -systemctl --user disable --now mj-arcana.service
    -rm -f ~/.config/systemd/user/mj-arcana.service
    systemctl --user daemon-reload
    @echo "removed mj-arcana.service"

# Tail the service log
logs:
    journalctl --user -u mj-arcana.service -f
