#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 1 ]] || { echo "usage: $0 <extracted-package-root>" >&2; exit 1; }
app="$1/Frame.app"
cli="$1/bin/frame"
"$(dirname "$0")/verify-signatures.sh" developer-id "$app" "$cli"
xcrun stapler validate "$app"
# A bare CLI cannot carry a stapled ticket. Check its own online ticket for
# every architecture; the app's stapling success alone is insufficient.
for target in "$app" "$cli"; do
    for arch in arm64 x86_64; do
        codesign --verify --strict --arch "$arch" --check-notarization -R '=notarized' "$target"
    done
done
spctl --assess --type execute --verbose=2 "$app"
echo "Verified extracted distribution signatures, stapled app ticket, online app/CLI tickets and app Gatekeeper assessment."
