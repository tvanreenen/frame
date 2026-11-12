# Frame distribution qualification

The ownership migration preserved the existing `v3.2.0` bytes and signing identity. That release was not qualified for notarization or Hardened Runtime. New release tooling adds those gates for future artifacts; it does not rebuild, replace, or retroactively qualify a published release. The app stays `Frame`, the CLI/cask token stays `frame`, and the application identifier and signing team remain `com.frame.app` and `9Q355KSV85`. The debug identity remains separate.

## Local credential setup

Frame uses the operator's Developer ID Application certificate and a named `notarytool` Keychain profile. The profile is a local credential reference, not an Apple application identifier. Key's existing release scripts use `key-notary` under the same team; Frame can use that profile without changing Key or issuing a new signing certificate. Set `FRAME_NOTARY_PROFILE` explicitly to the profile available on the release Mac. No default profile is silently assumed.

If the existing profile is missing on this Mac, restore it through the operator's established credential process or create a local profile interactively:

```sh
xcrun notarytool store-credentials tvr-works-notary --team-id 9Q355KSV85
export FRAME_NOTARY_PROFILE=tvr-works-notary
```

The tool prompts for the Apple ID and app-specific password and validates them before saving them in the Keychain. Create an app-specific password through [Apple's account workflow](https://support.apple.com/en-us/102654) if needed. Enter credentials only in the local prompt; do not put them in source, shell history, PRs, chat, or ordinary CI. No private key export or new certificate is required. A differently named profile is equally valid; pass its name in `FRAME_NOTARY_PROFILE`.

## Automated evidence and its limits

The release builder requires Hardened Runtime, valid Developer ID Application signatures from the existing team, secure timestamps, stable signing identifiers, and no sandbox/debug/runtime-exception entitlements. All checks inspect both arm64 and x86_64 signatures. The app remains outside App Sandbox because Frame uses Accessibility APIs; enabling Hardened Runtime does not enable App Sandbox or add permission exceptions.

The submitted ZIP contains both executables. The accepted result and downloaded Apple log must agree on the submission ID and the exact submitted ZIP hash. The app is stapled before the final archive is created. Extracted final bytes must retain the staple, pass signature validation, satisfy the online `notarized` requirement for every app/CLI architecture, and pass the app's Gatekeeper assessment. The CLI uses Apple's online ticket lookup because a standalone executable cannot be stapled. Offline first use of the standalone CLI is not promised by this ZIP layout. See [Apple's notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) and [ticket behavior](https://developer.apple.com/forums/thread/720093).

These checks assess artifacts without starting the window manager. They do not establish a real quarantined first launch, actual Accessibility access, login-item restoration, native Intel execution, or minimum-supported-macOS execution. The existing PR workflow remains credential-free; its real universal ad-hoc package exercises Hardened Runtime/signature mechanics, while external-tool fixtures test failure boundaries without contacting Apple.

## Acceptance before publication

Use a disposable macOS VM or a designated test Mac with a snapshot. Record the OS, architecture, Homebrew version, exact source commit, archive SHA-256, Apple submission ID, and the local service/assessment logs. Avoid the maintainer's working installation until a concrete artifact and explicit device handoff are ready. Keep automatic release/tap publication paused while acceptance is incomplete.

1. Download the exact candidate through a quarantine-aware route such as a browser. Record that quarantine is present, extract normally, and launch from Finder with the network available. Expect the normal identified-developer confirmation, successful launch, and no unidentified-developer or damaged-app rejection. Exercise the app's actual tiling/hotkey behavior after granting Accessibility through the normal OS flow. Do not remove quarantine, disable Gatekeeper, or reset the permission database to make the test pass.
2. Test app first launch offline from a fresh snapshot, using the stapled candidate. Record this separately from online acceptance. Test the standalone CLI online using the candidate's real installed path and a harmless command such as `--version`; record its separate ticket behavior. A bare CLI's lack of an offline staple remains a distribution constraint.
3. On a second snapshot, install the preserved `v3.2.0` from the personal route. Record app/CLI versions, the Homebrew receipt's source tap, a configuration marker or hash, existing Accessibility approval, and the existing login-item state. Move through the actual forwarding metadata and upgrade to the genuinely newer candidate through `tvr-works/tap/frame`. Do not use uninstall/reinstall as proof of the ordinary upgrade path.
4. Confirm the installed version and organization receipt, preserved configuration and Accessibility approval, working tiling and CLI communication, and a single login item. Log out/in or reboot in the test environment and confirm the intended auto-start behavior. Record any required user confirmation rather than treating it as automatic continuity.
5. Retain evidence and qualify native Intel and macOS 13 runtime separately if those environments are available. Universal compilation is evidence of the archive architectures, not execution on both platforms. If an environment is unavailable, record the gap explicitly before deciding release scope.

The first new release must use a genuine patch version, such as `v3.2.1`, after review and qualification. A draft may be used to distribute the exact acceptance candidate; once it is published, its tag and assets stay fixed. Publish the source release, dispatch the organization tap separately, review its proposed cask update, and verify the real Homebrew upgrade. The existing `v3.2.0` same-version migration only proved forwarding and optional receipt refresh; it did not prove a newer-version upgrade.

## Qualification record

| Gate | Evidence/status |
| --- | --- |
| Existing signing identity | Developer ID Application certificate for team `9Q355KSV85` is available on the inspected release Mac. No certificate or product identity change is planned. |
| Existing notarization setup | Key's scripts reference `key-notary`; `notarytool` reported that profile missing on this Mac during preparation. A usable local profile is required before Apple submission. |
| Local and hosted mechanical checks | Record exact candidate checks in the distribution-hardening PR. They do not replace Apple acceptance. |
| Apple acceptance and final artifact trust | Pending a usable profile and signed candidate; do not claim notarization from fixture tests or ad-hoc CI. |
| Quarantined first launch and ordinary upgrade | Pending the exact notarized candidate and designated test environment. |
| Accessibility/login continuity and platform coverage | Pending real-device acceptance; preserve existing grants and record OS/architecture coverage. |

This record must be updated with observed outcomes as gates complete. Failed acceptance blocks publication; use a forward fix and a newly qualified candidate rather than a quarantine workaround.
