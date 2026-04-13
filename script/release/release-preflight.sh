#!/bin/bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh
source ./script/identity.sh

build_version=""
tap_dir="$FRAME_HOMEBREW_TAP_DIR"
codesign_identity="${FRAME_CODESIGN_IDENTITY:-}"
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --tap-dir) tap_dir="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        *) echo "Unknown option $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$build_version" ]]; then
    echo "--build-version is mandatory (example: 0.12.3)" >&2
    exit 1
fi

if ! [[ "$build_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]]; then
    echo "Invalid --build-version '$build_version'. Expected semantic-style version." >&2
    exit 1
fi

require_command git
require_command just
require_command gh
require_command swift
require_command xcodebuild
require_command curl

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

tag="v$build_version"
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
        echo "For unsigned local validation builds, use --codesign-identity -." >&2
        exit 1
    fi
    codesign_identity="${identities[0]}"
fi

if [[ ! -d "$tap_dir" ]]; then
    echo "Homebrew tap directory not found: $tap_dir" >&2
    exit 1
fi
if [[ ! -d "$tap_dir/Casks" ]]; then
    echo "Homebrew tap Casks directory not found: $tap_dir/Casks" >&2
    exit 1
fi
if ! git -C "$tap_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Homebrew tap directory is not a git repository: $tap_dir" >&2
    exit 1
fi
if ! git -C "$tap_dir" diff --quiet || ! git -C "$tap_dir" diff --cached --quiet; then
    echo "Homebrew tap working tree must be clean before releasing." >&2
    exit 1
fi
if [[ -n "$(git -C "$tap_dir" ls-files --others --exclude-standard)" ]]; then
    echo "Homebrew tap has untracked files. Commit or remove them before releasing." >&2
    exit 1
fi

tap_branch="$(git -C "$tap_dir" rev-parse --abbrev-ref HEAD)"
if [[ "$tap_branch" != "main" ]]; then
    echo "Homebrew tap must be on 'main' (current: $tap_branch)." >&2
    exit 1
fi

echo "✅ Preflight OK"
echo "   Version: $build_version"
echo "   Repo branch: $current_branch"
echo "   Codesign identity: $codesign_identity"
echo "   Tap dir: $tap_dir"
