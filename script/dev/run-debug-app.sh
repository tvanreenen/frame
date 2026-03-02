#!/bin/bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh
source ./script/identity.sh

derived_data_path=".debug/.xcode-build"
app_path="$derived_data_path/Build/Products/Debug/${FRAME_PRODUCT_NAME_DEBUG}.app"

if [[ ! -d "$app_path" ]]; then
    echo "Debug app bundle not found at $app_path. Run 'just build' first." >&2
    exit 1
fi

/usr/bin/osascript -e "tell application id \"$FRAME_BUNDLE_ID_DEBUG\" to quit" >/dev/null 2>&1 || true
open -n "$app_path"
