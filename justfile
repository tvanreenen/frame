set shell := ["bash", "-euo", "pipefail", "-c"]

# Show available recipes.
default:
    @just --list --unsorted

# Install or update local dev tools from Brewfile.
setup:
    brew bundle --file Brewfile

# Build the debug app bundle.
build:
    ./script/dev/build-debug-app.sh

# Launch the built debug app.
run:
    ./script/dev/run-debug-app.sh

# Run the Swift unit test suite.
test:
    swift test

# Run CLI smoke checks against debug artifacts.
smoke:
    ./script/dev/smoke.sh

# Run pre-commit checks: unit tests, smoke checks, and format/lint verification.
check:
    just test
    just smoke
    ./script/dev/format.sh --verify

# Apply formatting and lint fixes.
fmt:
    ./script/dev/format.sh

# Remove local build artifacts.
clean:
    bash -euo pipefail -c 'source ./script/identity.sh; rm -rf "$HOME/Library/Developer/Xcode/DerivedData/${FRAME_XCODE_SCHEME}-*" ./.build ./.debug ./.xcode-build'

# Regenerate generated version/hash files and the Xcode project.
regen:
    ./script/dev/generate.sh

# Build release artifacts (zip + checksums) for a version.
release-build VERSION:
    bash -euo pipefail -c 'args=(--build-version "{{VERSION}}"); if [[ -n "${FRAME_CODESIGN_IDENTITY:-}" ]]; then args+=(--codesign-identity "$FRAME_CODESIGN_IDENTITY"); fi; ./script/release/build-release.sh "${args[@]}"'

# Generate the Homebrew cask for a GitHub release version.
release-cask VERSION:
    ./script/release/build-brew-cask.sh --build-version "{{VERSION}}"

# Reset Accessibility permission for the local debug app.
reset-accessibility:
    ./script/dev/reset-accessibility-permission-for-debug.sh
