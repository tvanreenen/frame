#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

# Use only a disposable CI version. --version exits before the daemon starts.
build_version=0.0.0
expected_version="$build_version+$(git rev-parse --short HEAD)"
archive="$(pwd)/dist/Frame-v$build_version.zip"
inspection_dir="$(mktemp -d "${TMPDIR:-/tmp}/frame-ci-package.XXXXXX")"
trap 'rm -rf "$inspection_dir"' EXIT

(cd dist && shasum -a 256 -c checksums.txt)
ditto -x -k "$archive" "$inspection_dir"
package_root="$inspection_dir/Frame-v$build_version"
app="$package_root/Frame.app"
cli="$package_root/bin/frame"

test -f "$package_root/LICENSE"
test -d "$package_root/licenses"
test -f "$app/Contents/Resources/default-config.toml"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = com.frame.app
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" = "$build_version"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$app/Contents/Info.plist")" = 13.0
codesign --verify --deep --strict "$app"
codesign --verify --strict "$cli"

for binary in "$app/Contents/MacOS/Frame" "$cli"; do
    test -x "$binary"
    test "$("$binary" --version)" = "$expected_version"
    architectures="$(lipo -archs "$binary")"
    [[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]]
done
git diff --exit-code -- Sources/Common/versionGenerated.swift Sources/Common/gitHashGenerated.swift Package.resolved
echo "Ad-hoc universal package, metadata, executable permissions, signatures, and checksum verified."
