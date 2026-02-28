#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh
source ./script/identity.sh

./script/check-uncommitted-files.sh

rm -rf "$HOME/Library/Developer/Xcode/DerivedData/${FRAME_XCODE_SCHEME}-*"
rm -rf ./.xcode-build

rm -rf "${FRAME_XCODE_SCHEME}.xcodeproj"
./generate.sh
