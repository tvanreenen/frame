#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh
source ./script/identity.sh

build_version="0.0.0-SNAPSHOT"
codesign_identity="$FRAME_CODESIGN_IDENTITY_DEFAULT"
while test $# -gt 0; do
    case $1 in
        --build-version) build_version="$2"; shift 2;;
        --codesign-identity) codesign_identity="$2"; shift 2;;
        *) echo "Unknown option $1" > /dev/stderr; exit 1 ;;
    esac
done

#############
### BUILD ###
#############

./build-shell-completion.sh

./generate.sh
./script/check-uncommitted-files.sh
./generate.sh --build-version "$build_version" --codesign-identity "$codesign_identity" --generate-git-hash

swift build -c release --arch arm64 --arch x86_64 --product "$FRAME_CLI_NAME" -Xswiftc -warnings-as-errors # CLI

# todo: make xcodebuild use the same toolchain as swift
# toolchain="$(plutil -extract CFBundleIdentifier raw ~/Library/Developer/Toolchains/swift-6.1-RELEASE.xctoolchain/Info.plist)"
# xcodebuild -toolchain "$toolchain" \
# Unfortunately, Xcode 16 fails with:
#     2025-05-05 15:51:15.618 xcodebuild[4633:13690815] Writing error result bundle to /var/folders/s1/17k6s3xd7nb5mv42nx0sd0800000gn/T/ResultBundle_2025-05-05_15-51-0015.xcresult
#     xcodebuild: error: Could not resolve package dependencies:
#       <unknown>:0: warning: legacy driver is now deprecated; consider avoiding specifying '-disallow-use-new-driver'
#     <unknown>:0: error: unable to execute command: <unknown>

rm -rf .release && mkdir .release

xcode_configuration="Release"
xcodebuild -version
xcodebuild-pretty .release/xcodebuild.log clean build \
    -scheme "$FRAME_XCODE_SCHEME" \
    -destination "generic/platform=macOS" \
    -configuration "$xcode_configuration" \
    -derivedDataPath .xcode-build

git checkout .

cp -r ".xcode-build/Build/Products/$xcode_configuration/${FRAME_PRODUCT_NAME}.app" .release
cp -r ".build/apple/Products/Release/$FRAME_CLI_NAME" .release

################
### SIGN CLI ###
################

codesign -s "$codesign_identity" ".release/$FRAME_CLI_NAME"

################
### VALIDATE ###
################

expected_layout=$(cat <<EOF
.release/${FRAME_PRODUCT_NAME}.app
.release/${FRAME_PRODUCT_NAME}.app/Contents
.release/${FRAME_PRODUCT_NAME}.app/Contents/_CodeSignature
.release/${FRAME_PRODUCT_NAME}.app/Contents/_CodeSignature/CodeResources
.release/${FRAME_PRODUCT_NAME}.app/Contents/MacOS
.release/${FRAME_PRODUCT_NAME}.app/Contents/MacOS/${FRAME_PRODUCT_NAME}
.release/${FRAME_PRODUCT_NAME}.app/Contents/Resources
.release/${FRAME_PRODUCT_NAME}.app/Contents/Resources/default-config.toml
.release/${FRAME_PRODUCT_NAME}.app/Contents/Resources/AppIcon.icns
.release/${FRAME_PRODUCT_NAME}.app/Contents/Resources/Assets.car
.release/${FRAME_PRODUCT_NAME}.app/Contents/Info.plist
.release/${FRAME_PRODUCT_NAME}.app/Contents/PkgInfo
EOF
)

if test "$expected_layout" != "$(find ".release/${FRAME_PRODUCT_NAME}.app")"; then
    echo "!!! Expect/Actual layout don't match !!!"
    find ".release/${FRAME_PRODUCT_NAME}.app"
    exit 1
fi

check-universal-binary() {
    if ! file "$1" | grep --fixed-string -q "Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64"; then
        echo "$1 is not a universal binary"
        exit 1
    fi
}

check-contains-hash() {
    hash=$(git rev-parse HEAD)
    if ! strings "$1" | grep --fixed-string "$hash" > /dev/null; then
        echo "$1 doesn't contain $hash"
        exit 1
    fi
}

check-universal-binary ".release/${FRAME_PRODUCT_NAME}.app/Contents/MacOS/${FRAME_PRODUCT_NAME}"
check-universal-binary ".release/${FRAME_CLI_NAME}"

check-contains-hash ".release/${FRAME_PRODUCT_NAME}.app/Contents/MacOS/${FRAME_PRODUCT_NAME}"
check-contains-hash ".release/${FRAME_CLI_NAME}"

codesign -v ".release/${FRAME_PRODUCT_NAME}.app"
codesign -v ".release/${FRAME_CLI_NAME}"

############
### PACK ###
############

cp -r ./legal ".release/${FRAME_RELEASE_PREFIX}$build_version/legal"
cp -r .shell-completion ".release/${FRAME_RELEASE_PREFIX}$build_version/shell-completion"
cd .release
    mkdir -p "${FRAME_RELEASE_PREFIX}$build_version/bin" && cp -r "$FRAME_CLI_NAME" "${FRAME_RELEASE_PREFIX}$build_version/bin"
    cp -r "${FRAME_PRODUCT_NAME}.app" "${FRAME_RELEASE_PREFIX}$build_version"
    zip -r "${FRAME_RELEASE_PREFIX}$build_version.zip" "${FRAME_RELEASE_PREFIX}$build_version"
cd -

#################
### Brew Cask ###
#################
for cask_name in "$FRAME_CASK_STABLE" "$FRAME_CASK_DEV"; do
    ./script/build-brew-cask.sh \
        --cask-name "$cask_name" \
        --zip-uri ".release/${FRAME_RELEASE_PREFIX}$build_version.zip" \
        --build-version "$build_version"
done
