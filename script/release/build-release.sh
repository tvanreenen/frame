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

if ! [[ "$build_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]]; then
    echo "Invalid --build-version '$build_version'. Expected semantic-style version (example: 0.12.3 or 0.12.3-rc.1)." >&2
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
        echo "For unsigned local smoke builds, use --codesign-identity -." >&2
        exit 1
    fi
    codesign_identity="${identities[0]}"
fi

echo "Using codesign identity: $codesign_identity"

dist_dir="$FRAME_DIST_DIR"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/${FRAME_RELEASE_WORK_PREFIX}.XXXXXX")"
stage_dir="$work_dir/stage"
build_dir="$work_dir/.build"
xcode_build_dir="$work_dir/.xcode-build"

cleanup() {
    rm -rf "$work_dir"
}
trap cleanup EXIT

if [[ -z "$dist_dir" || "$dist_dir" == "/" ]]; then
    echo "Refusing to use invalid dist dir: '$dist_dir'" >&2
    exit 1
fi

rm -rf "$dist_dir"
mkdir -p "$dist_dir" "$stage_dir"

#############
### BUILD ###
#############

swift build \
    -c release \
    --build-path "$build_dir" \
    --arch arm64 \
    --arch x86_64 \
    --product "$FRAME_CLI_NAME" \
    -Xswiftc -warnings-as-errors # CLI

xcode_configuration="Release"
xcodebuild -version
xcodebuild-pretty "$work_dir/xcodebuild.log" clean build \
    -scheme "$FRAME_XCODE_SCHEME" \
    -destination "generic/platform=macOS" \
    -configuration "$xcode_configuration" \
    -derivedDataPath "$xcode_build_dir" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$codesign_identity"

cp -r "$xcode_build_dir/Build/Products/$xcode_configuration/${FRAME_PRODUCT_NAME}.app" "$stage_dir"
cp -r "$build_dir/apple/Products/Release/$FRAME_CLI_NAME" "$stage_dir"

app_bundle="$stage_dir/${FRAME_PRODUCT_NAME}.app"
cli_binary="$stage_dir/${FRAME_CLI_NAME}"

################
### SIGN CLI ###
################

codesign -s "$codesign_identity" "$cli_binary"

################
### VALIDATE ###
################

required_paths=(
    "$app_bundle/Contents"
    "$app_bundle/Contents/_CodeSignature/CodeResources"
    "$app_bundle/Contents/MacOS/${FRAME_PRODUCT_NAME}"
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

check-universal-binary() {
    if ! file "$1" | grep --fixed-string -q "Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64"; then
        echo "$1 is not a universal binary"
        exit 1
    fi
}

check-universal-binary "$app_bundle/Contents/MacOS/${FRAME_PRODUCT_NAME}"
check-universal-binary "$cli_binary"

codesign --verify --deep --strict "$app_bundle"
codesign --verify --strict "$cli_binary"

# TODO: Add notarization + stapling here before packaging.
# Suggested flow:
# 1) Submit "$app_bundle" and "$cli_binary" to notary service.
# 2) Wait for success.
# 3) Staple ticket to "$app_bundle".

############
### PACK ###
############

release_root="$stage_dir/${FRAME_RELEASE_PREFIX}$build_version"
mkdir -p "$release_root/bin"
cp -r "$cli_binary" "$release_root/bin"
cp -r "$app_bundle" "$release_root"
cp ./LICENSE "$release_root/LICENSE"
cp -r ./licenses "$release_root/licenses"

zip_filename="${FRAME_RELEASE_PREFIX}$build_version.zip"
zip_path="$dist_dir/$zip_filename"
(
    cd "$stage_dir"
    zip -r "$(pwd)/../$zip_filename" "${FRAME_RELEASE_PREFIX}$build_version"
)
mv "$work_dir/$zip_filename" "$zip_path"

zip_sha="$(shasum -a 256 "$zip_path" | awk '{print $1}')"
printf "%s  %s\n" "$zip_sha" "$zip_filename" > "$dist_dir/checksums.txt"
