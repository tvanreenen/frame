#!/bin/bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh
source ./script/identity.sh

./script/dev/smoke-build.sh -Xswiftc -warnings-as-errors

"./.debug/${FRAME_CLI_NAME}" -h > /dev/null
"./.debug/${FRAME_CLI_NAME}" --help > /dev/null

version_short_output="$("./.debug/${FRAME_CLI_NAME}" -v)"
version_long_output="$("./.debug/${FRAME_CLI_NAME}" --version)"

if [[ "$version_short_output" != "$version_long_output" ]]; then
    echo "Version output mismatch between -v and --version." >&2
    exit 1
fi

line_count="$(printf '%s\n' "$version_long_output" | wc -l | tr -d ' ')"
if [[ "$line_count" != "1" ]]; then
    echo "Expected exactly 1 line in --version output, got $line_count." >&2
    printf '%s\n' "$version_long_output" >&2
    exit 1
fi

if ! printf '%s\n' "$version_long_output" | grep -Eq "^0\\.0\\.0-dev\\+[0-9a-f]{7,40}$"; then
    echo "Unexpected --version output." >&2
    printf '%s\n' "$version_long_output" >&2
    exit 1
fi

doctor_output=''
if doctor_output="$("./.debug/${FRAME_CLI_NAME}" doctor)"; then
    echo "Expected 'frame doctor' to exit non-zero when daemon is not running." >&2
    exit 1
fi

if ! printf '%s\n' "$doctor_output" | grep -Fxq "CLI Version: $version_long_output"; then
    echo "Unexpected CLI Version line in doctor output." >&2
    printf '%s\n' "$doctor_output" >&2
    exit 1
fi

if ! printf '%s\n' "$doctor_output" | grep -Fxq "Daemon Version: Not Running"; then
    echo "Unexpected Daemon Version line in doctor output." >&2
    printf '%s\n' "$doctor_output" >&2
    exit 1
fi

if ! printf '%s\n' "$doctor_output" | grep -Fxq "Versions Match: Unknown (daemon not running)"; then
    echo "Unexpected Versions Match line in doctor output." >&2
    printf '%s\n' "$doctor_output" >&2
    exit 1
fi

if ! printf '%s\n' "$doctor_output" | grep -Fxq "Config Location: Unknown"; then
    echo "Unexpected Config Location line in doctor output." >&2
    printf '%s\n' "$doctor_output" >&2
    exit 1
fi

if ! printf '%s\n' "$doctor_output" | grep -Fxq "Config Status: Unknown (daemon not running)"; then
    echo "Unexpected Config Status line in doctor output." >&2
    printf '%s\n' "$doctor_output" >&2
    exit 1
fi

echo
echo "✅ CLI smoke checks passed"
