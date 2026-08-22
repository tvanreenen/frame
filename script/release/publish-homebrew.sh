#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")/../.."
source ./script/identity.sh
source ./script/release/release-version.sh

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <v-prefixed-version>" >&2
    exit 1
fi

release_version="$1"
validate_release_version "$release_version"

if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI is required. Run 'brew install gh'." >&2
    exit 1
fi

release_details=""
if ! release_details="$(
    gh release view "$release_version" \
        --repo "$FRAME_REPO_SLUG" \
        --json isDraft,tagName,url \
        --template '{{.tagName}}|{{.isDraft}}|{{.url}}{{"\n"}}' 2>/dev/null
)"; then
    echo "Could not confirm published Frame release $release_version; it may be missing or unreadable." >&2
    echo "Create and publish the Frame release before requesting its Homebrew update." >&2
    exit 1
fi
IFS='|' read -r release_tag release_is_draft release_url <<< "$release_details"
if [[ "$release_tag" != "$release_version" ]]; then
    echo "GitHub returned release $release_tag, expected $release_version." >&2
    exit 1
fi
if [[ "$release_is_draft" != "false" ]]; then
    echo "GitHub release $release_version is still a draft." >&2
    echo "Review and publish it before requesting its Homebrew update." >&2
    exit 1
fi

echo "Confirmed published source release: $release_url"
gh workflow run "$FRAME_HOMEBREW_WORKFLOW" \
    --repo "$FRAME_HOMEBREW_TAP" \
    --ref main \
    -f package=frame \
    -f "version=$release_version"

echo "Dispatched the Homebrew tap update for Frame $release_version."
echo "Follow it with: gh run list --repo $FRAME_HOMEBREW_TAP --workflow $FRAME_HOMEBREW_WORKFLOW"
