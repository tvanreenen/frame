# Bundled CLI for v3.3.0

Frame's CLI controls the local window-manager app. Starting with v3.3.0, the release contains one CLI executable at `Frame.app/Contents/MacOS/frame`, beside the app executable `FrameApp`. The app remains `Frame.app`, the shell command remains `frame`, and signing identifiers remain `com.frame.app` and `frame` under team `9Q355KSV85`. Bundle IDs, configuration/socket paths, login identity and command behavior do not change.

## Layout and signing

The previous release put a separately signed CLI in the archive's `bin` directory. A bare executable cannot carry a stapled ticket and relied on online ticket discovery. Embedding it gives the app one signed code hierarchy and a stapled ticket containing the nested code's hashes. This follows Key's bundle layout. It supports offline distribution in principle, but does not prove CLI-first offline execution on a fresh Mac; that acceptance test remains required.

The app's internal executable changes from `Frame` to `FrameApp` because `Frame` and `frame` are the same filename on ordinary case-insensitive Mac volumes. `CFBundleExecutable` follows the new internal name. Product/bundle/signing names stay stable, and Debug keeps its existing build path. The Swift CLI still exits early for `--version`/`--help` and otherwise connects to the same daemon socket; it does not start the app or use its enclosing bundle to change configuration discovery.

The builder copies the universal CLI into the built app, signs the CLI with its existing identifier and no app entitlements, then re-signs the enclosing app with its existing identifier and app entitlements. Signing proceeds inside out without `codesign --deep`. The outer re-sign preserves Xcode's designated requirement, and the builder compares it before and after embedding so the code identity used by macOS and Homebrew cannot silently change. Verification still uses deep/strict app validation and checks both executables' architectures, signing identities, Hardened Runtime, timestamps and entitlements. The complete payload is submitted to Apple, the app is stapled, and final extracted bytes pass the existing distribution checks before version execution and checksum generation.

Retaining an independent CLI copy would preserve the old distribution boundary and online first-use constraint. Moving to a signed installer package could also carry a ticket but would add installer ownership, receipts and uninstall behavior. A nested executable keeps the current ZIP/app/cask model and avoids a second installed copy.

## Archive and manual-install compatibility

The ZIP retains `Frame-v<version>/Frame.app`, licenses and `bin/frame`. `bin/frame` is now a relative symlink to `../Frame.app/Contents/MacOS/frame`, so existing archive-relative invocations keep working without a duplicate executable. Extract with Finder, `ditto`, or another tool that preserves ZIP symlinks. Do not move only `bin` out of the extracted tree. The tap verifier accepts only this fixed internal link, creates it after regular-file extraction, and rejects arbitrary links, paths escaping the root and case-colliding entries.

For a manual installation, move the complete `Frame.app` to `/Applications`, then link the embedded executable into a directory on your PATH:

```sh
mkdir -p ~/.local/bin
ln -s /Applications/Frame.app/Contents/MacOS/frame ~/.local/bin/frame
```

If a manual `frame` file or link already exists, inspect `command -v frame` and its target before replacing that specific command with the link above. Existing scripts and key bindings continue using `frame`; do not uninstall the app, remove configuration or reset Accessibility grants. Copying the executable out of the app creates a standalone distribution again and loses the bundle's stapled-ticket availability; it is not the supported offline installation route.

## Homebrew rollout and rollback

Integrate the tap compatibility change before publishing v3.3.0. Its cask keeps the legacy archive path for versions below 3.3.0 and uses `#{appdir}/Frame.app/Contents/MacOS/frame` with target `frame` thereafter. Its archive/native verifiers recognize both contracts. The public 3.2.1 version and SHA-256 stay unchanged until an independently approved new release updates them.

A normal `brew upgrade --cask tvr-works/tap/frame` removes the old link using its installed cask metadata, installs the new app and links its embedded CLI. No manual uninstall/reinstall is part of this transition. Keep the app at its installed location so its symlink remains valid. Rollback must use the matching old cask and archive together; do not point an old cask at the new archive or replace a published tag/asset. Configuration and permission identity are not migration state to delete.

## Verification and release gate

PR CI builds a disposable ad-hoc 3.3.0 candidate and verifies the nested signatures, both universal executables, version/plist metadata, checksum and compatibility link. The package job also installs the actual published 3.2.1 baseline through a temporary local cask on a disposable macOS runner, then performs an ordinary upgrade to its locally built candidate. It checks link replacement, exact versions, receipt origin/version, deep signatures, a preserved configuration marker and complete removal, without starting the window-manager daemon. No CI binary is uploaded as a distributable release.

This proves packaging and Homebrew link/receipt mechanics. It does not qualify Developer ID notarization, Gatekeeper, Accessibility/login continuity or offline first execution. Before publication, submit/staple the exact Developer ID candidate and use a fresh macOS snapshot with no prior execution/assessment of those bytes. Download and extract with quarantine retained, disconnect the test environment from the network before any candidate command or app launch, then invoke the installed `frame --version` and `frame --help` first, followed by app launch. Record offline CLI-first separately from an app-first run and from an online warmed-cache check. Repeat the real 3.2.1 upgrade with existing grants and login state, and retain native Intel/minimum-macOS coverage gaps explicitly. Do not disconnect the maintainer's working Mac or clear its trust/permission databases to simulate this test.

The [initial hosted bundle qualification](https://github.com/tvr-works/frame/actions/runs/43152998512) passed all four jobs on production head `4443275f`, including 210 application tests, the universal ad-hoc package and the actual Homebrew upgrade/removal above. An isolated local Developer ID build also passed nested signatures and retained app/CLI designated requirements identical to installed v3.2.1. Its Apple submission could not read the Keychain profile and returned no submission ID; no notarization, final manifest, tag or release resulted. Missing/malformed submission responses now retain evidence and fail with a concise diagnostic, covered by a portable regression test. Fresh-snapshot CLI-first offline execution remains unverified.
