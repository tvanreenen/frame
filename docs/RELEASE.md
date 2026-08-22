# Releasing Frame

Frame owns its build, signing, release archive, checksum manifest, annotated tag, and GitHub release. The Homebrew tap owns cask rendering, verification, tests, and the update pull request. Frame never checks out, edits, commits to, or stores a credential for the tap.

Use the `just` recipes below as the maintainer interface. Every version argument must be a stable, v-prefixed Semantic Version such as `v0.12.3`. Prerelease versions, build metadata, omitted `v` prefixes, and numeric components with leading zeroes are rejected.

## Release order

1. Start from an up-to-date, clean `main` branch with the release signing identity available and GitHub CLI authenticated:

   ```sh
   git switch main
   git pull --ff-only
   gh auth status
   just release-preflight v0.12.3
   ```

   Set `FRAME_CODESIGN_IDENTITY` when preflight cannot select the intended `Developer ID Application` identity unambiguously. `FRAME_CODESIGN_IDENTITY=-` is only for unsigned local validation, not publication.

2. Build and stage the source release:

   ```sh
   just release v0.12.3
   ```

   The command repeats preflight, runs the test suite, builds and signs Frame, validates the staged binaries and version metadata, creates `dist/Frame-v0.12.3.zip` and `dist/checksums.txt`, pushes the annotated `v0.12.3` tag, and creates a draft GitHub release containing both files. Signing happens before packaging. Notarization is not currently automated; its defined integration point remains after signature validation and before packaging in `script/release/build-release.sh`.

3. Inspect the draft release before publishing it. Confirm the tag and title are `v0.12.3`, the generated notes are appropriate, and the only assets are:

   - `Frame-v0.12.3.zip`
   - `checksums.txt`

   Publish the draft only after those checks pass. A published release is immutable: do not replace its tag or assets.

4. At the separate Homebrew checkpoint, dispatch the tap workflow:

   ```sh
   just publish-homebrew v0.12.3
   ```

   This command refuses a missing or draft Frame release, then uses the operator's existing `gh` login to dispatch only `tvanreenen/homebrew-tap/.github/workflows/publish-package.yml` from `main` with `package=frame` and `version=v0.12.3`. It does not wait for the workflow or modify the tap.

5. Follow the tap run and review the pull request it creates:

   ```sh
   gh run list \
     --repo tvanreenen/homebrew-tap \
     --workflow publish-package.yml
   ```

   The tap independently downloads the published release, verifies its metadata, exact asset set, `checksums.txt`, and archive, renders the cask, runs Homebrew checks, and owns its update branch and pull request.

## Failure recovery

- If preflight, tests, or the build fails before the tag is created, fix the cause and rerun the same command and version.
- If local tag creation succeeds but the tag push fails, first confirm that `v0.12.3` does not exist on the remote. Delete only the local tag with `git tag -d v0.12.3`, then rerun. Never move an existing remote release tag.
- If the tag push succeeds but draft creation fails, keep the remote tag and built artifacts. Create the draft for that existing tag with `gh release create`, attaching `dist/Frame-v0.12.3.zip` and `dist/checksums.txt` and using the same draft, generated-notes, and title settings shown in `script/release/release.sh`.
- If review finds a problem while the release is still a draft, correct the draft before publication. If the release has already been published, leave it unchanged and release a new patch version.
- If `publish-homebrew` reports a missing or draft release, finish source-release publication and rerun it. The command is intentionally independent of `just release`.
- If the tap workflow fails because the published release is invalid, publish a corrected new Frame version; do not replace published assets. For a transient tap or GitHub failure, rerun `just publish-homebrew` with the same version. The tap workflow treats an already-current cask or existing matching pull request idempotently.
