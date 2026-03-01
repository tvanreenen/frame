#!/bin/bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh
source ./script/identity.sh

rebuild=1
while test $# -gt 0; do
    case $1 in
        --dont-rebuild) rebuild=0; shift ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if test $rebuild == 1; then
    ./script/release/build-release.sh --build-version 0.0.0-local
fi

PATH="$PATH:$(brew --prefix)/bin"
export PATH

brew list "$FRAME_CASK_STABLE" > /dev/null 2>&1 && brew uninstall "$FRAME_CASK_STABLE"
which brew-install-path > /dev/null 2>&1 || brew install "$FRAME_HOMEBREW_TAP/brew-install-path"

# Override HOMEBREW_CACHE to force using the freshly generated local cask artifact.
rm -rf /tmp/frame-from-sources-brew-cache
HOMEBREW_CACHE=/tmp/frame-from-sources-brew-cache brew install-path "./.release/${FRAME_CASK_STABLE}.rb"
