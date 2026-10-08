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

# systemd cannot read .env itself: it is bash, and `export KEY=value` is silently ignored,
# which would leave every key unset — and since both mj services are key-gated, the unit
# would start, log happily, and register nothing. So translate it. Holds API keys, hence
# mode 600 and never inside the repo.
# Generate ~/.config/mj/env from .env (strips `export`, mode 600)
systemd-env:
    @mkdir -p ~/.config/mj
    @sed -E 's/^[[:space:]]*export[[:space:]]+//' .env | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' > ~/.config/mj/env
    @chmod 600 ~/.config/mj/env
    @echo "wrote ~/.config/mj/env ($(grep -c . ~/.config/mj/env) vars, mode 600)"

# Install mj-arcana as a systemd user service, pointing at this checkout.
install-service: build systemd-env
    @mkdir -p ~/.config/systemd/user
    @sed 's|@MJ_DIR@|{{justfile_directory()}}|g' deploy/mj-arcana.service > ~/.config/systemd/user/mj-arcana.service
    systemctl --user daemon-reload
    systemctl --user enable --now mj-arcana.service
    @sleep 2
    systemctl --user --no-pager --lines=0 status mj-arcana.service

# Remove the service (leaves ~/.config/mj/env alone — it holds your keys).
uninstall-service:
    -systemctl --user disable --now mj-arcana.service
    -rm -f ~/.config/systemd/user/mj-arcana.service
    systemctl --user daemon-reload
    @echo "removed mj-arcana.service"

# Tail the service log
logs:
    journalctl --user -u mj-arcana.service -f
