#!/bin/bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh
source ./script/identity.sh

./script/dev/generate.sh --ignore-xcodeproj
swift build "$@"

rm -rf .debug && mkdir .debug
cp -r ".build/debug/${FRAME_CLI_NAME}" .debug
cp -r ".build/debug/${FRAME_DEBUG_APP_BINARY}" .debug
