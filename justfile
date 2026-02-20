default:
    @just --list

# Install shard dependencies
deps:
    shards install

# Build the binary
build: deps
    mkdir -p bin
    crystal build src/minanime.cr -o bin/minanime

# Build with optimizations
release: deps
    mkdir -p bin
    crystal build src/minanime.cr -o bin/minanime --release

# Run in development mode
run: deps
    crystal run src/minanime.cr

# Type-check without generating code
check:
    crystal build src/minanime.cr --no-codegen

# Run specs
test:
    crystal spec

# Clean build artifacts
clean:
    rm -rf bin lib .shards
