# Releasing Frame

Frame owns its build, signing, release archive, checksum manifest, annotated tag, and GitHub release. The Homebrew tap owns cask rendering, verification, tests, and the update pull request. Frame never checks out, edits, commits to, or stores a credential for the tap.

Pull requests are verified by [credential-free CI](CI.md), including a disposable ad-hoc package check. Those CI packages are not Developer ID-signed releases or notarized artifacts. The source repository and verified Homebrew route are now under `tvr-works`; the [ownership migration record](OWNERSHIP-TRANSFER.md) preserves the transfer baseline and rationale.

Use the `just` recipes below as the maintainer interface. Every version argument must be a stable, v-prefixed Semantic Version such as `v0.12.3`. Prerelease versions, build metadata, omitted `v` prefixes, and numeric components with leading zeroes are rejected.

The v3.3.0 [bundled CLI design and rollout](BUNDLED-CLI.md) changes the internal app executable to `FrameApp`, embeds `frame`, and preserves archive-relative `bin/frame` as a fixed internal symlink. Integrate the companion tap compatibility PR before publishing v3.3.0; existing releases and assets remain unchanged.

## Release order

1. Start from an up-to-date, clean `main` branch with the release signing identity available and GitHub CLI authenticated:

   ```sh
   git switch main
   git pull --ff-only
   gh auth status
   export FRAME_NOTARY_PROFILE=tvr-works-notary
   just release-preflight v0.12.3
   ```

   Set `FRAME_CODESIGN_IDENTITY` when preflight cannot select the intended `Developer ID Application` identity unambiguously. Distribution verification requires the existing team `9Q355KSV85`. Preflight rejects ad-hoc publication and checks that the selected notarization profile can authenticate before any build, tag, or release mutation. [Credential setup and device acceptance](DISTRIBUTION-QUALIFICATION.md) explain the local profile and remaining release gates.

2. Build and stage the source release:

   ```sh
   just release v0.12.3
   ```

   The command repeats preflight, runs the test suite, and builds the universal app and CLI with Hardened Runtime and secure signing timestamps. It checks Developer ID Application signatures, the existing team and signing identifiers, both architectures, entitlements, and version metadata. The complete package is submitted to Apple, including the CLI embedded in the app. Acceptance and the service log must match that exact submission and its SHA-256 before the app's ticket is stapled.

   The builder creates `dist/Frame-v0.12.3.zip`, extracts it into a fresh directory, and repeats distribution checks on the extracted payload: signatures, stapled app ticket, online notarization tickets for each app/CLI architecture, and the app's Gatekeeper assessment. Online ticket lookup has a short bounded retry; persistent failure stops the release. Only after these checks does the builder execute the extracted app/CLI's `--version` and require the expected version/commit metadata, then generate `dist/checksums.txt`. Qualification exposed temporary native CLI trust failures when version execution preceded notarization; the builder now assesses the unrun distribution first. A failed trust or version check stops before any tag or release is created. The app staple now carries the nested CLI's ticket. The per-code-item online checks remain release gates; fresh-system offline CLI-first execution remains an explicitly untested scenario and is not proven by a warm machine's successful lookup. This follows [Apple's custom notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

   Local evidence is retained in `dist/notarization/`: the submitted ZIP, submission result, Apple service log, and extracted-distribution check log. Review the service log for warnings even after acceptance. These files stay local and are not release assets or ordinary CI artifacts. After all checks succeed, the command pushes the annotated tag and creates a draft GitHub release containing only the final ZIP and checksum manifest.

3. Inspect the draft release before publishing it. Confirm the tag and title are `v0.12.3`, the generated notes are appropriate, and the only assets are:

   - `Frame-v0.12.3.zip`
   - `checksums.txt`

   Complete the [qualification record](DISTRIBUTION-QUALIFICATION.md) for the exact artifact, including passed checks and untested device scenarios, and obtain approval of that concrete release checkpoint before publishing the draft. A published release is immutable: do not replace its tag or assets.

4. At the separate Homebrew checkpoint, dispatch the tap workflow:

   ```sh
   just publish-homebrew v0.12.3
   ```

   This command refuses a missing or draft Frame release, then uses the operator's existing `gh` login to dispatch only `tvr-works/homebrew-tap/.github/workflows/publish-package.yml` from `main` with `package=frame` and `version=v0.12.3`. It does not wait for the workflow or modify the tap.

5. Follow the tap run and review the pull request it creates:

   ```sh
   gh run list \
     --repo tvr-works/homebrew-tap \
     --workflow publish-package.yml
   ```

   The tap independently downloads the published release, verifies its metadata, exact asset set, `checksums.txt`, and archive, renders the cask, runs Homebrew checks, and owns its update branch and pull request.

## Failure recovery

- If preflight, tests, or the build fails before the tag is created, fix the cause and rerun the same command and version.
- If notarization is rejected, inspect `dist/notarization/notary-log.json` and fix the reported cause. If waiting times out, Apple may still be processing the submission. Retain `dist/notarization/` before another build replaces `dist/`; use the recorded submission ID with `xcrun notarytool info`, `wait`, or `log` and the same Keychain profile to inspect it. A timeout, missing log, mismatched payload, failed staple, or failed extracted-distribution assessment cannot produce a release manifest or create a tag through `just release`. Rebuilding changes the submitted bytes and requires its own qualification; do not reuse an earlier acceptance for new bytes.
- If local tag creation succeeds but the tag push fails, first confirm that `v0.12.3` does not exist on the remote. Delete only the local tag with `git tag -d v0.12.3`, then rerun. Never move an existing remote release tag.
- If the tag push succeeds but draft creation fails, keep the remote tag and built artifacts. Create the draft for that existing tag with `gh release create`, attaching `dist/Frame-v0.12.3.zip` and `dist/checksums.txt` and using the same draft, generated-notes, and title settings shown in `script/release/release.sh`.
- If review finds a problem while the release is still a draft, correct the draft before publication. If the release has already been published, leave it unchanged and release a new patch version.
- If `publish-homebrew` reports a missing or draft release, finish source-release publication and rerun it. The command is intentionally independent of `just release`.
- If the tap workflow fails because the published release is invalid, publish a corrected new Frame version; do not replace published assets. For a transient tap or GitHub failure, rerun `just publish-homebrew` with the same version. The tap workflow treats an already-current cask or existing matching pull request idempotently.
