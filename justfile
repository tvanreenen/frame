set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

help:
    @just --list

setup:
    brew bundle --file Brewfile

build-debug:
    ./script/dev/build-debug.sh

dev:
    ./script/dev/build-debug.sh
    ./.debug/FrameApp

test:
    swift test

fmt:
    ./script/dev/format.sh

check:
    ./script/dev/run-tests.sh
    ./script/dev/format.sh --verify

clean:
    bash -euo pipefail -c 'source ./script/identity.sh; rm -rf "$HOME/Library/Developer/Xcode/DerivedData/${FRAME_XCODE_SCHEME}-*" ./.xcode-build "${FRAME_XCODE_SCHEME}.xcodeproj"; ./script/dev/generate.sh'

release-build VERSION:
    ./script/release/build-release.sh --build-version "{{VERSION}}" --codesign-identity "${FRAME_CODESIGN_IDENTITY:-frame-codesign-certificate}"

release-cask VERSION ZIP_URI CASK_NAME:
    ./script/build-brew-cask.sh --build-version "{{VERSION}}" --zip-uri "{{ZIP_URI}}" --cask-name "{{CASK_NAME}}"

release-publish VERSION CASK_REPO_PATH:
    ./script/publish-release.sh --build-version "{{VERSION}}" --cask-git-repo-path "{{CASK_REPO_PATH}}"

reset-accessibility:
    ./script/reset-accessibility-permission-for-debug.sh
