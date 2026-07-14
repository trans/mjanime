default:
    @just --list

# Install shard dependencies
deps:
    shards install

# Build the binary
build: deps
    mkdir -p bin
    crystal build src/mj.cr -o bin/mj

# Build the binary, do not update shards
compile:
    mkdir -p bin
    crystal build src/mj.cr -o bin/mj

# Build with optimizations
release: deps
    mkdir -p bin
    crystal build src/mj.cr -o bin/mj --release

# Run in development mode
run: deps
    crystal run src/mj.cr

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
    rm -rf bin lib .shards
