#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

fixtures_dir="Sources/AppBundleTests/fixtures/axDumps"
capture_script="./script/dev/capture-axdump.swift"
module_cache_dir="${TMPDIR:-/tmp}/frame-swift-module-cache"

usage() {
    cat <<EOF
Usage:
  ./script/dev/axdump-fixtures.sh list
  ./script/dev/axdump-fixtures.sh check
  ./script/dev/axdump-fixtures.sh capture <name> <window|dialog|popup> <true|false> [--overwrite]
  ./script/dev/axdump-fixtures.sh rename <old-name> <new-name>
  ./script/dev/axdump-fixtures.sh remove <name>

Notes:
  - Names can include subdirectories (e.g. scenario/foo_01)
  - The .json5 suffix is optional in names
EOF
}

normalize_name() {
    local name="$1"
    name="${name#./}"
    name="${name%.json5}"
    echo "$name"
}

fixture_path_from_name() {
    local name
    name="$(normalize_name "$1")"
    echo "$fixtures_dir/$name.json5"
}

require_fixture_exists() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "Fixture does not exist: $path" >&2
        exit 1
    fi
}

cmd="${1:-}"
case "$cmd" in
    list)
        find "$fixtures_dir" -type f -name '*.json5' | sort
        ;;
    check)
        swift test --filter AxWindowKindTest
        ;;
    capture)
        name="${2:-}"
        expected_type="${3:-}"
        expected_dialog_heuristic="${4:-}"
        overwrite_flag="${5:-}"
        if [[ -z "$name" || -z "$expected_type" || -z "$expected_dialog_heuristic" ]]; then
            usage
            exit 1
        fi
        output="$(fixture_path_from_name "$name")"
        mkdir -p "$(dirname "$output")"
        args=(
            "$capture_script"
            --output "$output"
            --expected-type "$expected_type"
            --expected-dialog-heuristic "$expected_dialog_heuristic"
        )
        if [[ "$overwrite_flag" == "--overwrite" ]]; then
            args+=(--overwrite)
        fi
        mkdir -p "$module_cache_dir"
        swift -module-cache-path "$module_cache_dir" "${args[@]}"
        ;;
    rename)
        old_name="${2:-}"
        new_name="${3:-}"
        if [[ -z "$old_name" || -z "$new_name" ]]; then
            usage
            exit 1
        fi
        src="$(fixture_path_from_name "$old_name")"
        dst="$(fixture_path_from_name "$new_name")"
        require_fixture_exists "$src"
        mkdir -p "$(dirname "$dst")"
        git mv "$src" "$dst"
        ;;
    remove)
        name="${2:-}"
        if [[ -z "$name" ]]; then
            usage
            exit 1
        fi
        src="$(fixture_path_from_name "$name")"
        require_fixture_exists "$src"
        git rm "$src"
        ;;
    *)
        usage
        exit 1
        ;;
esac
