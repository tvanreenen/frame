#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

# Use only a disposable CI version. --version exits before the daemon starts.
build_version="${FRAME_CI_BUILD_VERSION:-0.0.0}"
expected_version="$build_version+$(git rev-parse --short HEAD)"
archive="$(pwd)/dist/Frame-v$build_version.zip"
inspection_dir="$(mktemp -d "${TMPDIR:-/tmp}/frame-ci-package.XXXXXX")"
trap 'rm -rf "$inspection_dir"' EXIT

# Match the builder's single-entry manifest against the actual release ZIP.
if ! (cd dist && shasum -a 256 "Frame-v$build_version.zip") | cmp -s - dist/checksums.txt; then
    echo "checksums.txt must contain exactly the SHA-256 entry for Frame-v$build_version.zip" >&2
    exit 1
fi
ditto -x -k "$archive" "$inspection_dir"
package_root="$inspection_dir/Frame-v$build_version"
app="$package_root/Frame.app"
cli="$app/Contents/MacOS/frame"
test -L "$package_root/bin/frame"
test "$(readlink "$package_root/bin/frame")" = ../Frame.app/Contents/MacOS/frame

test -f "$package_root/LICENSE"
test -d "$package_root/licenses"
test -f "$app/Contents/Resources/default-config.toml"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = com.frame.app
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" = "$build_version"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$app/Contents/Info.plist")" = 13.0
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")" = FrameApp
script/release/verify-signatures.sh ad-hoc "$app" "$cli"

for binary in "$app/Contents/MacOS/FrameApp" "$cli"; do
    test -x "$binary"
    test "$("$binary" --version)" = "$expected_version"
    architectures="$(lipo -archs "$binary")"
    [[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]]
done
test "$("$package_root/bin/frame" --version)" = "$expected_version"
git diff --exit-code -- Sources/Common/versionGenerated.swift Sources/Common/gitHashGenerated.swift Package.resolved
echo "Ad-hoc universal package, metadata, executable permissions, signatures, and checksum verified."
