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

# Apply formatting and lint fixes, or pass through formatter flags like --verify.
format *ARGS:
    ./script/dev/format.sh {{ARGS}}

# Alias for `format`.
fmt *ARGS:
    @just format {{ARGS}}

# Remove local build artifacts.
clean:
    bash -euo pipefail -c 'source ./script/identity.sh; rm -rf "$HOME/Library/Developer/Xcode/DerivedData/${FRAME_XCODE_SCHEME}-*" ./.build ./.debug ./.xcode-build'

# Regenerate generated version/hash files and the Xcode project.
regen:
    ./script/dev/generate.sh

# Validate release prerequisites without publishing.
release-preflight VERSION:
    bash -euo pipefail -c 'args=(--build-version "{{VERSION}}"); if [[ -n "${FRAME_CODESIGN_IDENTITY:-}" ]]; then args+=(--codesign-identity "$FRAME_CODESIGN_IDENTITY"); fi; ./script/release/release-preflight.sh "${args[@]}"'

# Full release flow: preflight, tests, build, cask, tap update, tag push, and draft GitHub release.
release VERSION:
    bash -euo pipefail -c 'args=(--build-version "{{VERSION}}"); if [[ -n "${FRAME_CODESIGN_IDENTITY:-}" ]]; then args+=(--codesign-identity "$FRAME_CODESIGN_IDENTITY"); fi; ./script/release/release.sh "${args[@]}"'

# Reset Accessibility permission for the local debug app.
reset-accessibility:
    ./script/dev/reset-accessibility-permission-for-debug.sh
