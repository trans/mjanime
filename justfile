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
