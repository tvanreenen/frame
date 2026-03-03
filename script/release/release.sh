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

infer_release_level() {
    local version="$1"
    local previous_version
    local cmaj cmin cpatch pmaj pmin ppatch

    previous_version="$(git tag -l 'v*' --sort=-version:refname | head -n1)"
    previous_version="${previous_version#v}"
    if [[ -z "$previous_version" ]]; then
        echo "Release"
        return
    fi

    if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        echo "Release"
        return
    fi
    cmaj="${BASH_REMATCH[1]}"
    cmin="${BASH_REMATCH[2]}"
    cpatch="${BASH_REMATCH[3]}"

    if [[ ! "$previous_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        echo "Release"
        return
    fi
    pmaj="${BASH_REMATCH[1]}"
    pmin="${BASH_REMATCH[2]}"
    ppatch="${BASH_REMATCH[3]}"

    if (( cmaj > pmaj )); then
        echo "Major Release"
        return
    fi
    if (( cmin > pmin )); then
        echo "Minor Release"
        return
    fi
    if (( cpatch > ppatch )); then
        echo "Patch Release"
        return
    fi

    echo "Release"
}

preflight_args=(--build-version "$build_version" --tap-dir "$tap_dir")
if [[ -n "$codesign_identity" ]]; then
    preflight_args+=(--codesign-identity "$codesign_identity")
fi

echo "[1/8] Running preflight checks..."
./script/release/release-preflight.sh "${preflight_args[@]}"

echo "[2/8] Running unit tests..."
just test

echo "[3/8] Building release artifacts..."
build_args=(--build-version "$build_version")
if [[ -n "$codesign_identity" ]]; then
    build_args+=(--codesign-identity "$codesign_identity")
fi
./script/release/build-release.sh "${build_args[@]}"

echo "[4/8] Generating Homebrew cask..."
./script/release/build-brew-cask.sh --build-version "$build_version"

echo "[5/8] Updating Homebrew tap cask..."
cp "$FRAME_DIST_DIR/$FRAME_CASK_STABLE.rb" "$tap_dir/Casks/$FRAME_CASK_STABLE.rb"
git -C "$tap_dir" add "Casks/$FRAME_CASK_STABLE.rb"
if git -C "$tap_dir" diff --cached --quiet; then
    echo "No cask changes detected after copy: $tap_dir/Casks/$FRAME_CASK_STABLE.rb" >&2
    exit 1
fi
git -C "$tap_dir" commit -m "$FRAME_CASK_STABLE $build_version"
tap_branch="$(git -C "$tap_dir" rev-parse --abbrev-ref HEAD)"
git -C "$tap_dir" push origin "$tap_branch"

release_level="$(infer_release_level "$build_version")"
tag="v$build_version"
tag_message="$release_level"
release_title="$tag"

echo "[6/8] Creating and pushing annotated tag ($tag)..."
git tag -a "$tag" -m "$tag_message"
git push origin "$tag"

echo "[7/8] Creating draft GitHub release..."
gh release create "$tag" \
    "$FRAME_DIST_DIR/${FRAME_RELEASE_PREFIX}${build_version}.zip" \
    "$FRAME_DIST_DIR/checksums.txt" \
    --repo "$FRAME_REPO_SLUG" \
    --title "$release_title" \
    --draft \
    --generate-notes

echo "[8/8] Done."
echo "✅ Draft release created for $tag"
echo "   Release title: $release_title"
echo "   Tag message: $tag_message"
echo "   Homebrew tap updated: $tap_dir/Casks/$FRAME_CASK_STABLE.rb"
