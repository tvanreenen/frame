# Frame verification

See [CI-QUALIFICATION.md](CI-QUALIFICATION.md) for the recorded local and hosted success/failure/recovery evidence.

`Verify Frame` in `.github/workflows/ci.yml` verifies pull requests, pushes to `main` and `codex/**`, and manual dispatches. It has no distribution step. It does not create tags, releases, casks, or installable build artifacts on GitHub, and it does not use signing credentials, repository secrets, or tap access.

## Checks and their boundaries

| Job | Contract |
| --- | --- |
| Workflow and release contracts | Pinned actionlint validates the workflow; Bash parses tracked shell scripts; the existing shell suite checks version rejection and the source-release/tap-dispatch boundary. Python tests exercise false-green cases in the XCTest evidence and package checksum gates. |
| macOS checks and tests | Xcode 26.2 / Swift 6.2.3, matching `.swift-version`; checksum-pinned SwiftFormat and SwiftLint; locked package resolution; all three XCTest targets. The suites use synthetic accessibility fixtures and test platform services. No GUI or AX permission is requested. |
| Ad-hoc universal package | The existing release builder creates only a disposable `0.0.0` package using identity `-`. The packaged ZIP is extracted and checked for its checksum, app/CLI versions, bundle identity, minimum macOS version, executable permissions, universal architectures, licenses/resources, and valid ad-hoc signatures. Only `--version` is executed, which exits before the daemon starts; the app is never installed or launched as a window manager. |
| Required checks | Every preceding job must succeed. Failed, cancelled, or skipped dependencies cannot certify the branch. This is the suggested future required status check; this task does not change branch protections. |

All jobs run with repository read permission; the aggregate gate needs no token permission. Checkout does not persist credentials. Actions are pinned to full commit SHAs. Downloaded tools are pinned by version and SHA-256 in `script/ci/tools.json`, verified before extracting only the named executable into the checkout's ignored `.build/ci-tools/bin`.

Portable checks run on Ubuntu 24.04; Swift/AppKit and package checks require macOS 26. The pinned Xcode path deliberately fails if that toolchain disappears from the runner image. Update the path and `.swift-version` together after qualifying a replacement. The current package tests are small enough that a shared macOS job is clearer than sharding mutable session-based fixtures across multiple jobs.

Blacksmith is [available only for organization repositories](https://docs.blacksmith.sh/introduction/quickstart). Frame remains personal-account owned, so this workflow uses GitHub-hosted runners. The verified `tvr-works` installation and the runner qualification needed after transfer are recorded in [the ownership plan](OWNERSHIP-TRANSFER.md). This pass neither adds runner access nor changes billing.

## Test evidence and diagnostics

`swift test` must return success, and `verify-test-results.py` independently requires passed cases from `FrameEngineTests`, `FrameMacOSTests`, and `FrameUITests`. Their total must match completed XCTest bundle summaries. It accepts the combined bundle produced by Xcode 26.2 and separate bundles observed with newer SwiftPM. Empty Swift Testing XML reports do not prove XCTest execution. Unexpected skips and failures are rejected. The parsed per-target counts are retained with the process log.

Test/format reports are retained for three days. Portable and package logs are uploaded only after failure, also for three days. Package failures can preserve the raw Xcode log through the optional `FRAME_BUILD_LOG_DIR` environment variable; the release builder otherwise retains its original cleanup behavior. Diagnostic artifacts contain logs and test counts, never the ad-hoc app or release archive. Jobs have 3/10/25/30-minute limits; superseded branch runs are cancelled, while pushes to `main` are allowed to finish.

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

An ad-hoc signature is not a Developer ID signature or a notarization ticket. This CI verifies build/package mechanics; real display events, permission prompts, physical display rotation, hotkeys, and macOS trust behavior require separate device qualification. Universal compilation also does not replace native Intel or minimum-supported-macOS runtime qualification. The signed/manual distribution boundary remains in [RELEASE.md](RELEASE.md).
