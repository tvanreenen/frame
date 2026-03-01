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

#############
### BUILD ###
#############

rm -rf .release && mkdir .release

swift build \
    -c release \
    --build-path .release/.build \
    --arch arm64 \
    --arch x86_64 \
    --product "$FRAME_CLI_NAME" \
    -Xswiftc -warnings-as-errors # CLI

# todo: make xcodebuild use the same toolchain as swift
# toolchain="$(plutil -extract CFBundleIdentifier raw ~/Library/Developer/Toolchains/swift-6.1-RELEASE.xctoolchain/Info.plist)"
# xcodebuild -toolchain "$toolchain" \
# Unfortunately, Xcode 16 fails with:
#     2025-05-05 15:51:15.618 xcodebuild[4633:13690815] Writing error result bundle to /var/folders/s1/17k6s3xd7nb5mv42nx0sd0800000gn/T/ResultBundle_2025-05-05_15-51-0015.xcresult
#     xcodebuild: error: Could not resolve package dependencies:
#       <unknown>:0: warning: legacy driver is now deprecated; consider avoiding specifying '-disallow-use-new-driver'
#     <unknown>:0: error: unable to execute command: <unknown>

xcode_configuration="Release"
xcodebuild -version
xcodebuild-pretty .release/xcodebuild.log clean build \
    -scheme "$FRAME_XCODE_SCHEME" \
    -destination "generic/platform=macOS" \
    -configuration "$xcode_configuration" \
    -derivedDataPath .release/.xcode-build \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$codesign_identity"

cp -r ".release/.xcode-build/Build/Products/$xcode_configuration/${FRAME_PRODUCT_NAME}.app" .release
cp -r ".release/.build/apple/Products/Release/$FRAME_CLI_NAME" .release

################
### SIGN CLI ###
################

codesign -s "$codesign_identity" ".release/$FRAME_CLI_NAME"

################
### VALIDATE ###
################

app_bundle=".release/${FRAME_PRODUCT_NAME}.app"
cli_binary=".release/${FRAME_CLI_NAME}"
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

# TODO: Add notarization + stapling here before packaging/cask generation.
# Suggested flow:
# 1) Submit "$app_bundle" and "$cli_binary" to notary service.
# 2) Wait for success.
# 3) Staple ticket to "$app_bundle".

############
### PACK ###
############

release_root=".release/${FRAME_RELEASE_PREFIX}$build_version"
mkdir -p "$release_root/bin"
cp -r "$cli_binary" "$release_root/bin"
cp -r "$app_bundle" "$release_root"
cp ./LICENSE "$release_root/LICENSE"
cp -r ./licenses "$release_root/licenses"
(
    cd .release
    zip -r "${FRAME_RELEASE_PREFIX}$build_version.zip" "${FRAME_RELEASE_PREFIX}$build_version"
)

#################
### Brew Cask ###
#################
./script/release/build-brew-cask.sh \
    --zip-uri ".release/${FRAME_RELEASE_PREFIX}$build_version.zip" \
    --build-version "$build_version"
