#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 3 && ( "$1" == developer-id || "$1" == ad-hoc ) ]] || {
    echo "usage: $0 <developer-id|ad-hoc> <app> <cli>" >&2; exit 1;
}
mode="$1"
app="$2"
cli="$3"
entitlements="$(mktemp "${TMPDIR:-/tmp}/frame-entitlements.XXXXXX")"
trap 'rm -f "$entitlements"' EXIT
codesign --verify --deep --strict "$app"
codesign --verify --strict "$cli"
for target in "$app" "$cli"; do
    identifier=frame
    [[ "$target" != "$app" ]] || identifier=com.frame.app
    if [[ "$mode" == developer-id ]]; then
        requirement="anchor apple generic and identifier \"$identifier\" and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"9Q355KSV85\""
        codesign --verify --strict -R "=$requirement" "$target"
    fi
    for arch in arm64 x86_64; do
        metadata="$(codesign -d --verbose=4 --arch "$arch" "$target" 2>&1)"
        grep -Fqx "Identifier=$identifier" <<< "$metadata"
        grep -Eq '^CodeDirectory .*flags=.*[(,]runtime[,) ]' <<< "$metadata" || {
            echo "Missing Hardened Runtime: $target ($arch)" >&2; exit 1;
        }
        if [[ "$mode" == developer-id ]]; then
            grep -Fqx 'TeamIdentifier=9Q355KSV85' <<< "$metadata"
            grep -Eq '^Timestamp=.+$' <<< "$metadata" || {
                echo "Missing secure timestamp: $target ($arch)" >&2; exit 1;
            }
        else
            grep -Fqx 'Signature=adhoc' <<< "$metadata"
        fi
        codesign -d --entitlements - --xml --arch "$arch" "$target" > "$entitlements" 2>/dev/null
        python3 - "$entitlements" <<'PY'
import plistlib
from pathlib import Path
import sys
payload = Path(sys.argv[1]).read_bytes()
values = plistlib.loads(payload) if payload.strip() else {}
if (values.get('com.apple.security.get-task-allow', False)
        or values.get('com.apple.security.app-sandbox', False)
        or any(key.startswith('com.apple.security.cs.') for key in values)):
    sys.exit('Unexpected debug, sandbox, or Hardened Runtime exception entitlement')
PY
    done
done
echo "Verified $mode signatures, identities, Hardened Runtime and entitlements for both architectures."
