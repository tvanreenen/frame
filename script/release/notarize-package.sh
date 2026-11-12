#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 && -n "${FRAME_NOTARY_PROFILE:-}" ]] || {
    echo "usage: FRAME_NOTARY_PROFILE=<Keychain profile> $0 <package-root> <evidence-dir>" >&2; exit 1;
}
package_root="$(cd "$1" && pwd)"
mkdir -p "$2"
evidence="$(cd "$2" && pwd)"
submission="$evidence/submission.zip"
# Submit the complete payload, including the standalone CLI, before stapling.
ditto -c -k --keepParent "$package_root" "$submission"
submit_status=0
xcrun notarytool submit "$submission" --keychain-profile "$FRAME_NOTARY_PROFILE" \
    --wait --timeout 20m --output-format json > "$evidence/submission.json" || submit_status=$?
submission_id="$(python3 - "$evidence/submission.json" <<'PY'
import json
from pathlib import Path
import sys
import uuid
print(uuid.UUID(json.loads(Path(sys.argv[1]).read_text())['id']))
PY
)"
echo "Notary submission: $submission_id; evidence: $evidence"
# Retain the service log even for a completed rejection. On timeout, preserve
# the submission/evidence for inspection rather than issuing a tag or release.
xcrun notarytool log "$submission_id" --keychain-profile "$FRAME_NOTARY_PROFILE" "$evidence/notary-log.json"
if [[ "$submit_status" -ne 0 ]]; then
    echo "Notarization did not complete successfully; inspect $evidence before retrying." >&2
    exit "$submit_status"
fi
python3 "$(dirname "$0")/verify-notary-result.py" \
    "$evidence/submission.json" "$evidence/notary-log.json" "$submission"
xcrun stapler staple "$package_root/Frame.app"
xcrun stapler validate "$package_root/Frame.app"
