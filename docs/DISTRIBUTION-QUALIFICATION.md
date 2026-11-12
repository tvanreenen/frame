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

The submitted ZIP contains both executables. The accepted result and downloaded Apple log must agree on the submission ID and the exact submitted ZIP hash. The app is stapled before the final archive is created. Extracted final bytes must retain the staple, pass signature validation, satisfy the online `notarized` requirement for every app/CLI architecture, and pass the app's Gatekeeper assessment. Through v3.2.1, the standalone CLI relies on online ticket discovery. The v3.3.0 layout embeds it in the app so the stapled ticket is available with the code hierarchy; offline CLI-first acceptance remains a separate fresh-snapshot gate. [The bundle design](BUNDLED-CLI.md) records paths and rollout. See [Apple's notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) and [ticket behavior](https://developer.apple.com/forums/thread/720093).

Online ticket lookup has six attempts with five seconds between failures. Two real qualifications executed the native CLI's `--version` before notarization, then failed its online ticket check after Apple acceptance. The first later passed on unchanged bytes; the second exhausted the short retry window. After moving version execution behind ticket verification, a fresh build passed all four ticket lookups on the first attempt. An interaction with an early cached trust result is inferred from that ordering experiment. Keep executable version checks after trust verification; they must still match before the checksum manifest is produced. Persistent lookup failure blocks the manifest/tag/release, while signature, entitlement, stapling, and Gatekeeper checks fail immediately. A later successful assessment cannot qualify rebuilt or altered bytes.

These checks assess artifacts without starting the window manager. They do not establish a real quarantined first launch, actual Accessibility access, login-item restoration, native Intel execution, or minimum-supported-macOS execution. The existing PR workflow remains credential-free; its real universal ad-hoc package exercises Hardened Runtime/signature mechanics, while external-tool fixtures test failure boundaries without contacting Apple.

## Acceptance before publication

Use a disposable macOS VM or a designated test Mac with a snapshot. Record the OS, architecture, Homebrew version, exact source commit, archive SHA-256, Apple submission ID, and the local service/assessment logs. Avoid the maintainer's working installation until a concrete artifact and explicit device handoff are ready. Keep automatic release/tap publication paused while acceptance is incomplete.

1. Download the exact candidate through a quarantine-aware route such as a browser. Record that quarantine is present, extract normally, and launch from Finder with the network available. Expect the normal identified-developer confirmation, successful launch, and no unidentified-developer or damaged-app rejection. Exercise the app's actual tiling/hotkey behavior after granting Accessibility through the normal OS flow. Do not remove quarantine, disable Gatekeeper, or reset the permission database to make the test pass.
2. For v3.3.0, disconnect a fresh test snapshot before any candidate execution or assessment and invoke the installed embedded CLI's `--version` and `--help` first, with quarantine retained. Then test app launch offline. Record this separately from app-first, online and warmed-cache acceptance. Do not copy the CLI out of the bundle or clear a working Mac's trust database to simulate freshness. Historical standalone CLI releases retain their online first-use constraint.
3. On a second snapshot, install the published `v3.2.1` from the organization route, or record the actual older personal-tap installation being upgraded. Record app/CLI versions, the Homebrew receipt's source tap, a configuration marker or hash, existing Accessibility approval, and the existing login-item state. Move through the actual forwarding metadata and upgrade to the genuinely newer candidate through `tvr-works/tap/frame`. Do not use uninstall/reinstall as proof of the ordinary upgrade path.
4. Confirm the installed version and organization receipt, preserved configuration and Accessibility approval, working tiling and CLI communication, and a single login item. Log out/in or reboot in the test environment and confirm the intended auto-start behavior. Record any required user confirmation rather than treating it as automatic continuity.
5. Retain evidence and qualify native Intel and macOS 13 runtime separately if those environments are available. Universal compilation is evidence of the archive architectures, not execution on both platforms. If an environment is unavailable, record the gap explicitly before deciding release scope.

The original distribution-hardening release used `v3.2.1`; the bundled CLI targets `v3.3.0` after its own review and qualification. A draft may be used to distribute the exact acceptance candidate; once it is published, its tag and assets stay fixed. Publish the source release, dispatch the organization tap separately, review its proposed cask update, and verify the real Homebrew upgrade. The existing `v3.2.0` same-version migration only proved forwarding and optional receipt refresh; it did not prove a newer-version upgrade.

## Historical distribution-hardening record

The following table records the original tooling qualification before the actual v3.2.1 release. [PR 23](https://github.com/tvr-works/frame/pull/23) and the [published v3.2.1 notes](https://github.com/tvr-works/frame/releases/tag/v3.2.1) record the later accepted release and existing-Mac upgrade. These historical Apple submissions do not qualify the rebuilt v3.3.0 bundle. Its mechanical/signing evidence and remaining acceptance gates are recorded in [PR 24](https://github.com/tvr-works/frame/pull/24) and the [bundle design](BUNDLED-CLI.md).

| Gate | Evidence/status |
| --- | --- |
| Existing signing identity | Developer ID Application certificate for team `9Q355KSV85` is available on the inspected release Mac. No certificate or product identity change is planned. |
| Existing notarization setup | Key's scripts reference `key-notary`, which was missing on this Mac. The operator created `tvr-works-notary` locally under the existing team, and authentication succeeded on November 11, 2026. No credential is stored in the repository or CI. |
| Local and hosted mechanical checks | All 19 portable helper tests, release shell contracts, actionlint and new-script ShellCheck pass. Hosted checks at `1e9a33ca` and `e631e388` passed all four jobs, including all 210 application tests and the actual universal ad-hoc package with pinned Xcode 26.2 / Swift 6.2.3. The PR records qualification of the final ordering/docs head. |
| Apple acceptance and final artifact trust | The full signed builder passed at `7c8a17743c7e29c1d4d2fae9013547164398063b` on Xcode 27.2 / Swift 6.4.2 with disposable version `0.0.0`. Submission `19881fa7-2b9e-4a3f-b8a2-6b2407007a76` was Accepted with no issues; the submitted SHA-256 was `2200407377219e8d950abddb2c0b4048a4d5838f28fce7bb232f21e60eabccb0`. The final ZIP hash/manifest was `746cb1aa48459a33119d44513fb9d253e023db459b0d0ea7fbb4f77f92281b6e`. Its extracted app retained the staple, all app/CLI architecture tickets passed without retry, Gatekeeper reported `Notarized Developer ID`, and version checks passed before manifest creation. The organization tap's existing archive/signature/version gate also accepted this package. It is not a published release or a newer-version upgrade test. |
| Quarantined first launch and ordinary upgrade | Pending the exact notarized candidate and designated test environment. |
| Accessibility/login continuity and platform coverage | Pending real-device acceptance; preserve existing grants and record OS/architecture coverage. |

This record must be updated with observed outcomes as gates complete. Failed acceptance blocks publication; use a forward fix and a newly qualified candidate rather than a quarantine workaround.

The earlier submissions `fd568457-86f3-456c-94a5-9745bb032d9b` at `1e9a33ca` and `2da86c6e-7369-4ddf-af9a-cb08924f71c5` at `e631e388` were also Accepted with no reported issues, but the native CLI lookup failures above stopped both builds before a checksum manifest. Their local evidence was retained separately. Those rejected local builds establish that service acceptance alone cannot bypass the final trust gate.
