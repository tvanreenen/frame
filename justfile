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

# Run the Swift unit suite and release-contract shell tests.
test:
    swift test
    ./Tests/Shell/release-contract-test.sh

# Apply formatting and lint fixes, or pass through formatter flags like --verify.
format *ARGS:
    ./script/dev/format.sh {{ ARGS }}

# Alias for `format`.
fmt *ARGS:
    @just format {{ ARGS }}

# Remove local build artifacts.
clean:
    bash -euo pipefail -c 'source ./script/identity.sh; rm -rf "$HOME/Library/Developer/Xcode/DerivedData/${FRAME_XCODE_SCHEME}-*" ./.build ./.debug ./.xcode-build'

# Regenerate generated version/hash files and the Xcode project.
regen:
    ./script/dev/generate.sh

# Validate release prerequisites without publishing (VERSION must be vX.Y.Z).
release-preflight VERSION:
    bash -euo pipefail -c 'args=(--version "$1"); if [[ -n "${FRAME_CODESIGN_IDENTITY:-}" ]]; then args+=(--codesign-identity "$FRAME_CODESIGN_IDENTITY"); fi; ./script/release/release-preflight.sh "${args[@]}"' _ {{ quote(VERSION) }}

# Build, verify, tag, and create the draft GitHub release (VERSION must be vX.Y.Z).
release VERSION:
    bash -euo pipefail -c 'args=(--version "$1"); if [[ -n "${FRAME_CODESIGN_IDENTITY:-}" ]]; then args+=(--codesign-identity "$FRAME_CODESIGN_IDENTITY"); fi; ./script/release/release.sh "${args[@]}"' _ {{ quote(VERSION) }}

# Ask the tap to propose the published release's Homebrew update.
publish-homebrew VERSION:
    ./script/release/publish-homebrew.sh {{ quote(VERSION) }}

# Reset Accessibility permission for the local debug app.
reset-accessibility:
    ./script/dev/reset-accessibility-permission-for-debug.sh
