#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 1 ]] || { echo "usage: $0 <extracted-package-root>" >&2; exit 1; }
app="$1/Frame.app"
cli="$app/Contents/MacOS/frame"
"$(dirname "$0")/verify-signatures.sh" developer-id "$app" "$cli"
xcrun stapler validate "$app"
# The app staple carries the ticket for its nested CLI too. Continue checking
# each code item online as a release gate; offline CLI-first execution requires
# separate fresh-machine acceptance and is not established by these lookups.
check_notarization() {
    local target="$1" arch="$2" attempt
    echo "Checking notarization: $target ($arch)"
    # An accepted submission's ticket lookup can be transiently unavailable.
    # Retry only this online check; persistent failure still blocks packaging.
    for attempt in 1 2 3 4 5 6; do
        if codesign --verify --verbose=2 --strict --arch "$arch" --check-notarization -R '=notarized' "$target"; then
            return 0
        fi
        [[ "$attempt" -lt 6 ]] || return 1
        echo "Ticket lookup failed; retrying in 5 seconds ($attempt/6)." >&2
        sleep 5
    done
}
for target in "$app" "$cli"; do
    for arch in arm64 x86_64; do
        check_notarization "$target" "$arch"
    done
done
spctl --assess --type execute --verbose=2 "$app"
echo "Verified extracted distribution signatures, stapled app ticket, online app/CLI tickets and app Gatekeeper assessment."
