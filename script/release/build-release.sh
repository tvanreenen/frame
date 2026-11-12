#!/bin/bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh
source ./script/identity.sh

build_version=""
codesign_identity="${FRAME_CODESIGN_IDENTITY:-}"
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        *) echo "Unknown option $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$build_version" ]]; then
    echo "--build-version is mandatory (example: 0.12.3)" >&2
    exit 1
fi

if ! [[ "$build_version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "Invalid --build-version '$build_version'. Expected a stable Semantic Version without a v prefix (example: 0.12.3)." >&2
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

echo "Using codesign identity: $codesign_identity"

signing_mode=developer-id
timestamp_flag=--timestamp
if [[ "$codesign_identity" == - ]]; then
    signing_mode=ad-hoc
    timestamp_flag=--timestamp=none
elif [[ -z "${FRAME_NOTARY_PROFILE:-}" ]]; then
    echo "Set FRAME_NOTARY_PROFILE to an existing notarytool Keychain profile for distribution builds." >&2
    exit 1
fi

dist_dir="$FRAME_DIST_DIR"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/${FRAME_RELEASE_WORK_PREFIX}.XXXXXX")"
stage_dir="$work_dir/stage"
build_dir="$work_dir/.build"
xcode_build_dir="$work_dir/.xcode-build"

cleanup() {
    local exit_code=$?
    trap - EXIT
    if [[ $exit_code -ne 0 && -n "${FRAME_BUILD_LOG_DIR:-}" && -f "$work_dir/xcodebuild.log" ]]; then
        mkdir -p "$FRAME_BUILD_LOG_DIR" && cp "$work_dir/xcodebuild.log" "$FRAME_BUILD_LOG_DIR/xcodebuild.log" || true
    fi
    git restore Sources/Common/versionGenerated.swift Sources/Common/gitHashGenerated.swift >/dev/null 2>&1 || true
    rm -rf "$work_dir"
    exit "$exit_code"
}
trap cleanup EXIT

if [[ -z "$dist_dir" || "$dist_dir" == "/" ]]; then
    echo "Refusing to use invalid dist dir: '$dist_dir'" >&2
    exit 1
fi

rm -rf "$dist_dir"
mkdir -p "$dist_dir" "$stage_dir"

echo "[prep] Preparing generated version metadata..."
./script/dev/generate.sh --build-version "$build_version" --generate-git-hash --ignore-xcodeproj
expected_git_short_hash="$(git rev-parse --short HEAD)"
expected_display_version="${build_version}+${expected_git_short_hash}"

#############
### BUILD ###
#############

echo "[1/4] Building CLI ($FRAME_CLI_NAME)..."
cli_build_args=(
    -c release
    --build-path "$build_dir"
    --arch arm64
    --arch x86_64
    --product "$FRAME_CLI_NAME"
    -Xswiftc -warnings-as-errors
)
swift build "${cli_build_args[@]}"
# SwiftPM's output layout depends on its build backend.
cli_bin_dir="$(swift build "${cli_build_args[@]}" --show-bin-path)"

xcode_configuration="Release"
echo "[2/4] Building app bundle (${FRAME_PRODUCT_NAME}.app)..."
xcodebuild -version
xcodebuild-pretty "$work_dir/xcodebuild.log" build \
    -scheme "$FRAME_XCODE_SCHEME" \
    -destination "generic/platform=macOS" \
    -configuration "$xcode_configuration" \
    -derivedDataPath "$xcode_build_dir" \
    MARKETING_VERSION="$build_version" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$codesign_identity" \
    OTHER_CODE_SIGN_FLAGS="$timestamp_flag"

cp -r "$xcode_build_dir/Build/Products/$xcode_configuration/${FRAME_PRODUCT_NAME}.app" "$stage_dir"

app_bundle="$stage_dir/${FRAME_PRODUCT_NAME}.app"
app_requirement="$(codesign -dr - "$app_bundle" 2>&1 | sed -n 's/^designated => //p')"
[[ -n "$app_requirement" ]] || { echo 'Missing app designated requirement' >&2; exit 1; }
cli_binary="$app_bundle/Contents/MacOS/${FRAME_CLI_NAME}"
# Frame and frame collide on case-insensitive volumes. Release uses FrameApp.
cp "$cli_bin_dir/$FRAME_CLI_NAME" "$cli_binary"

################
### SIGN BUNDLE ###
################

# Sign nested code first, then seal it into the enclosing app. Do not use
# --deep for signing: the CLI keeps its own identifier and no app entitlements.
codesign -s "$codesign_identity" --identifier "$FRAME_CLI_NAME" --options runtime "$timestamp_flag" "$cli_binary"
codesign --force -s "$codesign_identity" --identifier "$FRAME_BUNDLE_ID_STABLE" \
    --options runtime "$timestamp_flag" --preserve-metadata=requirements \
    --entitlements resources/frame.entitlements "$app_bundle"
[[ "$(codesign -dr - "$app_bundle" 2>&1 | sed -n 's/^designated => //p')" == "$app_requirement" ]] || {
    echo 'Embedding the CLI changed the app designated requirement' >&2; exit 1;
}

################
### VALIDATE ###
################

required_paths=(
    "$app_bundle/Contents"
    "$app_bundle/Contents/_CodeSignature/CodeResources"
    "$app_bundle/Contents/MacOS/${FRAME_APP_BINARY}"
    "$app_bundle/Contents/Resources/default-config.toml"
    "$app_bundle/Contents/Resources/AppIcon.icns"
    "$app_bundle/Contents/Resources/Assets.car"
    "$app_bundle/Contents/Info.plist"
    "$app_bundle/Contents/PkgInfo"
    "$cli_binary"
)
for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
        echo "Missing required release artifact path: $path" >&2
        exit 1
    fi
done

app_binary="$app_bundle/Contents/MacOS/${FRAME_APP_BINARY}"

check-universal-binary() {
    if ! file "$1" | grep --fixed-string -q "Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64"; then
        echo "$1 is not a universal binary"
        exit 1
    fi
}

check-universal-binary "$app_bundle/Contents/MacOS/${FRAME_APP_BINARY}"
check-universal-binary "$cli_binary"

echo "[3/4] Validating signatures and binaries..."
./script/release/verify-signatures.sh "$signing_mode" "$app_bundle" "$cli_binary"

############
### PACK ###
############

release_root="$stage_dir/${FRAME_RELEASE_PREFIX}$build_version"
mkdir -p "$release_root/bin"
cp -r "$app_bundle" "$release_root"
# Preserve archive-relative callers without distributing a second executable.
ln -s "../${FRAME_PRODUCT_NAME}.app/Contents/MacOS/${FRAME_CLI_NAME}" "$release_root/bin/${FRAME_CLI_NAME}"
cp ./LICENSE "$release_root/LICENSE"
cp -r ./licenses "$release_root/licenses"

if [[ "$signing_mode" == developer-id ]]; then
    ./script/release/notarize-package.sh "$release_root" "$dist_dir/notarization"
fi

zip_filename="${FRAME_RELEASE_PREFIX}$build_version.zip"
zip_path="$dist_dir/$zip_filename"
(
    cd "$stage_dir"
    zip -yr "$(pwd)/../$zip_filename" "${FRAME_RELEASE_PREFIX}$build_version"
)
mv "$work_dir/$zip_filename" "$zip_path"

# Verify the bytes users will extract, including preservation of the stapled
# app ticket. A failed distribution check must not produce a release manifest.
version_root="$release_root"
if [[ "$signing_mode" == developer-id ]]; then
    mkdir "$work_dir/inspection"
    ditto -x -k "$zip_path" "$work_dir/inspection"
    version_root="$work_dir/inspection/${FRAME_RELEASE_PREFIX}$build_version"
    ./script/release/verify-distribution.sh "$version_root" \
        2>&1 | tee "$dist_dir/notarization/distribution-check.log"
fi

# Do not execute distribution code before notarization/ticket verification.
# Assess the unrun distribution first, then check its executable metadata.
cli_version_output="$("$version_root/${FRAME_PRODUCT_NAME}.app/Contents/MacOS/${FRAME_CLI_NAME}" --version)"
if [[ "$cli_version_output" != "$expected_display_version" ]]; then
    echo "Release metadata mismatch for CLI version." >&2
    echo "Expected: $expected_display_version" >&2
    echo "Actual:   $cli_version_output" >&2
    exit 1
fi
app_version_output="$("$version_root/${FRAME_PRODUCT_NAME}.app/Contents/MacOS/${FRAME_APP_BINARY}" --version)"
if [[ "$app_version_output" != "$expected_display_version" ]]; then
    echo "Release metadata mismatch for app daemon version." >&2
    echo "Expected: $expected_display_version" >&2
    echo "Actual:   $app_version_output" >&2
    exit 1
fi

zip_sha="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
printf "%s  %s\n" "$zip_sha" "$zip_filename" > "$dist_dir/checksums.txt"

echo "[4/4] Done. Wrote:"
echo "  $zip_path"
echo "  $dist_dir/checksums.txt"
