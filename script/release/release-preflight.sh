#!/bin/bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh
source ./script/identity.sh
source ./script/release/release-version.sh

release_version=""
codesign_identity="${FRAME_CODESIGN_IDENTITY:-}"
while test $# -gt 0; do
    case $1 in
        --version) release_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        *) echo "Unknown option $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$release_version" ]]; then
    echo "--version is mandatory (example: v0.12.3)" >&2
    exit 1
fi
validate_release_version "$release_version"

if [[ "$codesign_identity" == - ]]; then
    echo "Publication requires Developer ID signing; use build-release.sh for ad-hoc validation." >&2
    exit 1
fi
if [[ -z "${FRAME_NOTARY_PROFILE:-}" ]]; then
    echo "Set FRAME_NOTARY_PROFILE to an existing notarytool Keychain profile before releasing." >&2
    exit 1
fi

require_command git
require_command just
require_command gh
require_command swift
require_command xcodebuild
require_command xcrun
require_command python3

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree must be clean before releasing." >&2
    exit 1
fi
if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    echo "Working tree has untracked files. Commit or remove them before releasing." >&2
    exit 1
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" != "main" ]]; then
    echo "Release must be run from 'main' (current: $current_branch)." >&2
    exit 1
fi

tag="$release_version"
if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Run 'gh auth login'." >&2
    exit 1
fi

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "Tag already exists locally: $tag" >&2
    exit 1
fi
if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
    echo "Tag already exists on origin: $tag" >&2
    exit 1
fi
if gh release view "$tag" --repo "$FRAME_REPO_SLUG" >/dev/null 2>&1; then
    echo "GitHub release already exists: $tag" >&2
    exit 1
fi

if [[ -z "$codesign_identity" ]]; then
    identities=()
    while IFS= read -r identity; do
        identities+=("$identity")
    done < <(
        security find-identity -v -p codesigning 2>/dev/null \
            | awk -F'"' '/Developer ID Application:/ { print $2 }'
    )
    if [[ ${#identities[@]} -ne 1 ]]; then
        echo "Unable to auto-select 'Developer ID Application' identity (found ${#identities[@]})." >&2
        echo "Set FRAME_CODESIGN_IDENTITY or pass --codesign-identity explicitly." >&2
        exit 1
    fi
    codesign_identity="${identities[0]}"
fi

# Check access before tests/builds or any tag/release mutation. Credentials stay
# in the operator's Keychain; ordinary PR CI never invokes notarization.
xcrun notarytool history --keychain-profile "$FRAME_NOTARY_PROFILE" --output-format json >/dev/null

echo "✅ Preflight OK"
echo "   Version: $release_version"
echo "   Repo branch: $current_branch"
echo "   Codesign identity: $codesign_identity"
