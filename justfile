set shell := ["bash", "-euo", "pipefail", "-c"]

# Show available recipes.
default:
    @just --list --unsorted

# Install/update local development tools from Brewfile.
setup:
    brew bundle --file Brewfile

# Build debug CLI + app binaries into .build/.debug.
build-debug:
    ./script/dev/build-debug.sh

# Build and launch the debug app.
dev:
    ./script/dev/build-debug.sh
    ./.debug/FrameApp

# Run the Swift unit test suite.
test:
    swift test

# Apply formatting and lint fixes.
fmt:
    ./script/dev/format.sh

# Run normal pre-commit checks (tests + verify formatting/lint).
check:
    ./script/dev/run-tests.sh
    ./script/dev/format.sh --verify

# Remove local build artifacts and regenerate Xcode project.
clean:
    bash -euo pipefail -c 'source ./script/identity.sh; rm -rf "$HOME/Library/Developer/Xcode/DerivedData/${FRAME_XCODE_SCHEME}-*" ./.xcode-build "${FRAME_XCODE_SCHEME}.xcodeproj"; ./script/dev/generate.sh'

# Build release artifacts and cask for a version.
release-build VERSION:
    bash -euo pipefail -c 'args=(--build-version "{{VERSION}}"); if [[ -n "${FRAME_CODESIGN_IDENTITY:-}" ]]; then args+=(--codesign-identity "$FRAME_CODESIGN_IDENTITY"); fi; ./script/release/build-release.sh "${args[@]}"'

# Generate the Homebrew cask file for a specific artifact URI.
release-cask VERSION ZIP_URI:
    ./script/build-brew-cask.sh --build-version "{{VERSION}}" --zip-uri "{{ZIP_URI}}"

# Run the interactive release publishing helper.
release-publish VERSION CASK_REPO_PATH:
    ./script/publish-release.sh --build-version "{{VERSION}}" --cask-git-repo-path "{{CASK_REPO_PATH}}"

# Reset macOS Accessibility permission for local debug app.
reset-accessibility:
    ./script/reset-accessibility-permission-for-debug.sh
