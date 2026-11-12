# Frame verification

See [CI-QUALIFICATION.md](CI-QUALIFICATION.md) for the recorded local and hosted success/failure/recovery evidence.

`Verify Frame` in `.github/workflows/ci.yml` verifies all pull requests and manual dispatches. Pushes do not start additional runs before a PR exists or after it merges. It has no publication step. It does not publish tags, releases, casks, or installable build artifacts on GitHub, and it does not use Apple signing credentials, repository secrets, or write access to the shared tap.

## Checks and their boundaries

The first three jobs check automation, Frame's existing application tests, and the release package. `Overall CI result` combines their statuses without adding another test suite.

| Job | Contract |
| --- | --- |
| Check CI and release scripts | Pinned actionlint validates the workflow; Bash parses tracked shell scripts; the existing shell suite checks version rejection and the source-release/tap-dispatch boundary. Python tests exercise false-green cases in the XCTest evidence and package checksum gates. |
| Build and test Frame | Xcode 26.2 / Swift 6.2.3, matching `.swift-version`; checksum-pinned SwiftFormat and SwiftLint; locked package resolution; all three XCTest targets. The suites use synthetic accessibility fixtures and test platform services. No GUI or AX permission is requested. |
| Build and verify release package | The release builder creates a disposable ad-hoc `3.3.0` package using identity `-`. The extracted ZIP is checked for its checksum, app/CLI versions, bundle identity, minimum macOS version, executable permissions, universal architectures, resources, nested signatures and compatibility link. A temporary local Homebrew fixture then exercises an ordinary upgrade from published 3.2.1, checks link/receipt/configuration-marker continuity and removes the test installation. Only metadata/help commands are executed; the GUI daemon is never started. |
| Overall CI result | Every preceding job must succeed. Failed, cancelled, or skipped dependencies cannot certify the branch. This is the suggested future required status check; this task does not change branch protections. |

All jobs run with repository read permission; the aggregate gate needs no token permission. Checkout does not persist credentials. Actions are pinned to full commit SHAs. Downloaded tools are pinned by version and SHA-256 in `script/ci/tools.json`, verified before extracting only the named executable into the checkout's ignored `.build/ci-tools/bin`.

Portable checks use `blacksmith-2vcpu-ubuntu-2404`; Swift/AppKit and package checks use `blacksmith-6vcpu-macos-26`. The pinned Xcode 26.2 path deliberately fails if that toolchain disappears from the runner image. Update the path and `.swift-version` together after qualifying a replacement. The current package tests are small enough that a shared macOS job is clearer than sharding mutable session-based fixtures across multiple jobs.

Blacksmith is [available only for organization repositories](https://docs.blacksmith.sh/introduction/quickstart). The existing all-repository `tvr-works` installation covers Frame after its source transfer. The migration PR qualifies these labels, the pinned toolchain, the application tests, and the actual package build before switching the default branch. The required status remains `Overall CI result`; the transfer retains its GitHub Actions app binding, strict up-to-date requirement, and administrator enforcement. No installation selection or billing change is needed. Use an explicit manual dispatch on `main` for final-owner/default-branch qualification; automatic triggers remain PR-only.

## Test evidence and diagnostics

`swift test` must return success, and `verify-test-results.py` independently requires passed cases from `FrameEngineTests`, `FrameMacOSTests`, and `FrameUITests`. Their total must match completed XCTest bundle summaries. It accepts the combined bundle produced by Xcode 26.2 and separate bundles observed with newer SwiftPM. Empty Swift Testing XML reports do not prove XCTest execution. Unexpected skips and failures are rejected. The parsed per-target counts are retained with the process log.

Test/format reports are retained for three days. Portable and package logs are uploaded only after failure, also for three days. Package failures can preserve the raw Xcode log through the optional `FRAME_BUILD_LOG_DIR` environment variable; the release builder otherwise retains its original cleanup behavior. Diagnostic artifacts contain logs and test counts, never the ad-hoc app or release archive. Jobs have 3/10/25/30-minute limits; superseded runs for the same PR or manually selected ref are cancelled.

Before extracting a package, the verifier compares `checksums.txt` with the SHA-256 line computed for the expected ZIP. The manifest must use the builder's exact single-entry format. An unrelated-file checksum, an extra or duplicate entry, a missing file, or changed archive bytes fails validation before extraction.

## Local checks

The installed `actionlint`, SwiftFormat, and SwiftLint can be used for local checks. CI installs its exact pinned binaries rather than modifying global tools:

```sh
script/ci/check-portable.sh
script/dev/format.sh --verify
mkdir -p .build/ci-results
swift test --no-parallel --force-resolved-versions 2>&1 | tee .build/ci-results/swift-tests.log
python3 script/ci/verify-test-results.py .build/ci-results/swift-tests.log
```

Use Bash with `set -o pipefail` when piping test output. Package qualification must use a clean, isolated checkout because the existing builder generates version files temporarily and replaces that checkout's `dist/`:

```sh
FRAME_BUILD_LOG_DIR="$PWD/.build/ci-results" script/release/build-release.sh --build-version 0.0.0 --codesign-identity -
script/ci/verify-package.sh
```

The package check now requires Hardened Runtime on both architectures of both executables and checks their entitlements through the same signature verifier used for distribution. Ad-hoc validation explicitly omits the secure timestamp and notarization steps, so PR CI still has no signing identity, Apple credential, or Apple submission. Portable release-trust regressions cover rejected/incomplete notarization, wrong submission or payload, missing runtime/timestamp on either architecture, runtime exception entitlements, missing CLI tickets, failed stapling/assessment, and rejection of ad-hoc publication.

An ad-hoc signature is not a Developer ID signature or a notarization ticket. This CI verifies build/package mechanics; real display events, permission prompts, physical display rotation, hotkeys, and macOS trust behavior require separate device qualification. Universal compilation also does not replace native Intel or minimum-supported-macOS runtime qualification. The signed/manual distribution boundary remains in [RELEASE.md](RELEASE.md), with the acceptance procedure in [DISTRIBUTION-QUALIFICATION.md](DISTRIBUTION-QUALIFICATION.md).

## Bundled CLI upgrade qualification

The package job builds a disposable ad-hoc 3.3.0 candidate with `FrameApp` and `frame` in the app bundle and checks the fixed archive compatibility symlink. It uses a temporary local Homebrew fixture on the ephemeral runner to install the published 3.2.1 baseline and perform an ordinary upgrade to that candidate in a temporary app directory. It checks installed link replacement, versions, receipt origin/version, signatures, configuration marker preservation and removal. The GUI daemon is never started, and no built archive is uploaded. This test exercises Homebrew mechanics, not Developer ID trust or fresh-snapshot offline execution; those remain [distribution acceptance gates](BUNDLED-CLI.md#verification-and-release-gate). Workflow triggers, job names, credentials policy and required aggregate check are unchanged.
