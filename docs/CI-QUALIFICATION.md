# CI qualification record

Recorded November 11, 2026. The review branch is `codex/ci-hardening-transfer-plan`; the separate `codex/ci-qualification-probe` branch contains the deliberate failure and its revert. Neither is merged by this task. The original checkout remains on clean `main` at `a3cf2daf`.

## Local qualification

- All 210 XCTest cases passed: 113 in FrameEngineTests, 96 in FrameMacOSTests, and 1 in FrameUITests. These use test platform services and synthetic AX fixtures.
- The five Python evidence-gate tests passed, including combined/split XCTest bundle output, empty runs, missing targets, inconsistent totals, failures, and skips.
- Actionlint, Bash syntax, ShellCheck for the new CI shell scripts, and the existing release-contract suite passed. Checksum-pinned SwiftFormat 0.63.1 and SwiftLint 0.65.1 passed.
- The actual release builder produced a disposable `0.0.0` ad-hoc package. The ZIP checksum, extracted permissions/resources/licenses, stable bundle identity, minimum OS metadata, matching app/CLI versions, universal architectures, and signatures passed validation. No app was installed or launched as a window manager.

Local Swift was 6.4.2; hosted qualification pins Xcode 26.2 / Swift 6.2.3. The two test output layouts were observed and qualified, rather than assuming the workstation's output represented CI.

## Hosted evidence

| Purpose | Commit | Evidence and observed result |
| --- | --- | --- |
| Candidate verification | `95e2b567` | [Run 43063697748](https://github.com/tvanreenen/frame/actions/runs/43063697748): all four jobs passed, including the universal package and final required gate. Retained test JSON records the same 210 executed cases. |
| Controlled failure | `9b7e90c1` | [Run 43063791965](https://github.com/tvanreenen/frame/actions/runs/43063791965): an intentionally inverted existing model assertion failed in XCTest. The evidence check rejected the failure; macOS and Required checks failed; package validation was skipped. The nonempty `macos-test-results-1` artifact was retained for three days. |
| Recovery | `611d2a1e` | [Run 43064229578](https://github.com/tvanreenen/frame/actions/runs/43064229578): all four jobs passed after reverting the deliberate assertion. Its committed tree matches candidate `95e2b567` exactly; the final gate returned to green only after universal package validation passed. |

The first bootstrap run, [43062582604](https://github.com/tvanreenen/frame/actions/runs/43062582604), correctly stayed red when its evidence checker did not recognize Xcode 26.2's combined bundle report. Commit `94ddbe3f` fixed that format assumption and added regression coverage. Its downloaded process log independently verified all 210 cases. Superseded branch runs were cancelled as configured; they do not certify the branch.

## Remaining boundaries

GitHub reported macOS arm64 capacity delays; queued time is not an executed check. Diagnostic artifacts expire after three days, while these run/commit links preserve the qualification history. The repository had no protection rules or required reviews at baseline; this task did not add any. A maintainer enabled previously disabled Actions so hosted qualification could run.

The implementation uses no signing/distribution credentials and leaves the running Frame app untouched. It does not qualify real permission prompts, live window/monitor events, native Intel/minimum-macOS runtime behavior, Developer ID trust, or notarization. No source release, tag, shared tap, ownership transfer, app identity, or integration access was changed. The separate [ownership plan](OWNERSHIP-TRANSFER.md) describes the future approvals and migration gates.
