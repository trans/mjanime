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

# Type-check without generating code
check:
    crystal build src/mj.cr --no-codegen

# Run specs
test:
    crystal spec

# Clean build artifacts
clean:
    rm -rf bin lib .shards
