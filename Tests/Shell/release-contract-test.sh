#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$repo_root/script/release/release-version.sh"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

valid_versions=(v0.0.0 v0.12.3 v1.2.3 v10.20.30)
for release_version in "${valid_versions[@]}"; do
    validate_release_version "$release_version"
    actual="$(release_version_to_build_version "$release_version")"
    [[ "$actual" == "${release_version#v}" ]] || fail "unexpected build version for $release_version"
done

invalid_versions=(
    ""
    0.12.3
    v01.2.3
    v1.02.3
    v1.2.03
    v1.2
    v1.2.3.4
    v1.2.3-rc.1
    v1.2.3+build.1
    "v1.2.3 "
)
for release_version in "${invalid_versions[@]}"; do
    if validate_release_version "$release_version" >/dev/null 2>&1; then
        fail "accepted invalid release version: '$release_version'"
    fi
done

if "$repo_root/script/release/release-preflight.sh" --version 1.2.3 >/dev/null 2>&1; then
    fail "release preflight accepted a version without the v prefix"
fi
if "$repo_root/script/release/release.sh" --version 1.2.3 >/dev/null 2>&1; then
    fail "release flow accepted a version without the v prefix"
fi
if "$repo_root/script/release/build-release.sh" --build-version v1.2.3 >/dev/null 2>&1; then
    fail "internal release builder accepted a v-prefixed build version"
fi

if grep -Eq 'gh workflow run|publish-homebrew\.sh' "$repo_root/script/release/release.sh"; then
    fail "source release flow dispatches Homebrew automatically"
fi

test_dir="$(mktemp -d "${TMPDIR:-/tmp}/frame-release-contract.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
fake_bin="$test_dir/bin"
mkdir "$fake_bin"

cat > "$fake_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1 $2" == "release view" ]]; then
    [[ "${FAKE_RELEASE_STATE:-missing}" != "missing" ]] || exit 1
    printf '%s|%s|https://github.com/tvanreenen/frame/releases/tag/%s\n' \
        "${FAKE_RELEASE_TAG:-$3}" "$FAKE_RELEASE_STATE" "${FAKE_RELEASE_TAG:-$3}"
    exit
fi
if [[ "$1 $2" == "workflow run" ]]; then
    printf '%s\n' "$@" > "$FAKE_GH_LOG"
    echo "https://github.com/tvanreenen/homebrew-tap/actions"
    exit
fi

echo "unexpected gh invocation: $*" >&2
exit 1
EOF
chmod +x "$fake_bin/gh"

export PATH="$fake_bin:$PATH"
export FAKE_GH_LOG="$test_dir/gh-workflow-args"
publish_script="$repo_root/script/release/publish-homebrew.sh"

run_publish() {
    set +e
    publish_output="$("$publish_script" "$@" 2>&1)"
    publish_status=$?
    set -e
}

rm -f "$FAKE_GH_LOG"
export FAKE_RELEASE_STATE=false
run_publish v1.2.3-rc.1
[[ $publish_status -ne 0 ]] || fail "publish accepted a prerelease version"
assert_contains "$publish_output" "Expected a stable v-prefixed Semantic Version"
[[ ! -e "$FAKE_GH_LOG" ]] || fail "invalid version dispatched the tap workflow"

rm -f "$FAKE_GH_LOG"
export FAKE_RELEASE_STATE=missing
run_publish v1.2.3
[[ $publish_status -ne 0 ]] || fail "publish accepted a missing release"
assert_contains "$publish_output" "may be missing or unreadable"
[[ ! -e "$FAKE_GH_LOG" ]] || fail "missing release dispatched the tap workflow"

rm -f "$FAKE_GH_LOG"
export FAKE_RELEASE_STATE=true
run_publish v1.2.3
[[ $publish_status -ne 0 ]] || fail "publish accepted a draft release"
assert_contains "$publish_output" "release v1.2.3 is still a draft"
[[ ! -e "$FAKE_GH_LOG" ]] || fail "draft release dispatched the tap workflow"

rm -f "$FAKE_GH_LOG"
export FAKE_RELEASE_STATE=false
export FAKE_RELEASE_TAG=v1.2.4
run_publish v1.2.3
[[ $publish_status -ne 0 ]] || fail "publish accepted a mismatched release tag"
assert_contains "$publish_output" "returned release v1.2.4, expected v1.2.3"
[[ ! -e "$FAKE_GH_LOG" ]] || fail "mismatched release dispatched the tap workflow"

rm -f "$FAKE_GH_LOG"
export FAKE_RELEASE_STATE=false
unset FAKE_RELEASE_TAG
run_publish v1.2.3
[[ $publish_status -eq 0 ]] || fail "published release was not dispatched: $publish_output"
assert_contains "$publish_output" "Confirmed published source release"
assert_contains "$publish_output" "Dispatched the Homebrew tap update"

expected_args="$test_dir/expected-gh-workflow-args"
printf '%s\n' \
    workflow \
    run \
    publish-package.yml \
    --repo \
    tvanreenen/homebrew-tap \
    --ref \
    main \
    -f \
    package=frame \
    -f \
    version=v1.2.3 > "$expected_args"
diff -u "$expected_args" "$FAKE_GH_LOG" || fail "tap workflow dispatch arguments changed"

echo "release contract tests passed"
