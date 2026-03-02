#!/bin/bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh
source ./script/identity.sh

codesign_identity="${FRAME_CODESIGN_IDENTITY:--}"
derived_data_path=".debug/.xcode-build"
app_path="$derived_data_path/Build/Products/Debug/${FRAME_PRODUCT_NAME_DEBUG}.app"

./script/dev/generate.sh --build-version "0.0.0-dev" --codesign-identity "$codesign_identity"

mkdir -p .debug
xcodebuild-pretty .debug/xcodebuild.log clean build \
    -scheme "$FRAME_XCODE_SCHEME" \
    -configuration Debug \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$derived_data_path" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$codesign_identity"

if [[ ! -d "$app_path" ]]; then
    echo "Debug app bundle not found at $app_path" >&2
    exit 1
fi

open "$app_path"
