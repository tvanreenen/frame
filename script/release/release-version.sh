#!/usr/bin/env bash

# The maintainer-facing release contract accepts stable, v-prefixed SemVer only.
validate_release_version() {
    local release_version="${1:-}"
    if [[ ! "$release_version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
        echo "Invalid release version '$release_version'. Expected a stable v-prefixed Semantic Version (example: v0.12.3)." >&2
        return 1
    fi
    return 0
}

# Strip the prefix only when crossing into build tooling's internal version format.
release_version_to_build_version() {
    local release_version="${1:-}"
    validate_release_version "$release_version" || return
    printf '%s\n' "${release_version#v}"
}
