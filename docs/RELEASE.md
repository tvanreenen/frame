# Release

This project keeps Homebrew release support. Use `just` commands as the primary interface.

## Inputs and conventions

- Version format: semantic-style string (example: `0.12.3`)
- Tag format: `v<version>` (example: `v0.12.3`)
- Release zip: `Frame-v<version>.zip`
- Cask: `frame`

## Build release artifacts

```bash
just release-build <version>
```

Example:

```bash
just release-build 0.12.3
```

Signing identity behavior:

- If `FRAME_CODESIGN_IDENTITY` (or `--codesign-identity`) is provided, that value is used.
- Otherwise, the build auto-selects from Keychain only when there is exactly one valid `Developer ID Application` identity.
- If none or multiple are found, the build fails with a clear message so you can pick explicitly.
- For unsigned local smoke builds, use:

```bash
FRAME_CODESIGN_IDENTITY=- just release-build 0.12.3
```

This builds:

- `dist/Frame-v<version>.zip`
- `dist/checksums.txt`

Build intermediates are created in a temporary work directory and removed automatically.

## Preflight checks

Run preflight only:

```bash
just release-preflight <version>
```

Preflight validates:

- clean git tree in `frame` repo
- current branch is `main`
- tag/release `v<version>` does not already exist
- `gh` auth is valid
- signing identity is resolvable
- Homebrew tap repo exists, is clean, and on `main`

Default Homebrew tap path is `~/Code/homebrew-tap` and can be overridden with `FRAME_HOMEBREW_TAP_DIR`.

## One-command release

```bash
just release <version>
```

This runs:

1. preflight checks
2. `just test`
3. `just release-build <version>`
4. `just release-cask <version>`
5. copy `dist/frame.rb` into `$FRAME_HOMEBREW_TAP_DIR/Casks/frame.rb`, commit, push
6. create/push annotated tag `v<version>` with inferred title:
   - `Major Release`
   - `Minor Release`
   - `Patch Release`
   - fallback `Release`
7. create draft GitHub release with attached:
   - release title: `v<version>`
   - `dist/Frame-v<version>.zip`
   - `dist/checksums.txt`

### Version metadata gate

`just release-build <version>` now hard-fails if version metadata is stale or inconsistent.

The release script regenerates compile-time metadata with the requested build version and current git short hash, then validates staged binaries:

- `bin/frame --version` must equal `<version>+<git_short_hash>`
- `Frame.app` daemon binary (`Frame.app/Contents/MacOS/Frame --version`) must equal `<version>+<git_short_hash>`

If either check fails, the release build exits non-zero before packaging.

## Notarization (planned)

Notarization is not yet automated in `just release-build`.

When added, it should run after signing/validation and before zipping:

1. Submit the staged app bundle and CLI binary to Apple notarization.
2. Wait for notarization success.
3. Staple the notarization ticket to the staged app bundle.
4. Then package `dist/Frame-v<version>.zip`.

## Generate cask manually

```bash
just release-cask <version>
```

`just release-cask` always writes a GitHub release URL into `dist/frame.rb`:

`https://github.com/tvanreenen/frame/releases/download/v<version>/Frame-v<version>.zip`

## Publish manually

If you don't want the one-command flow, manual steps are still:

1. Run checks and build artifacts:

```bash
just test
just release-build 0.12.3
```

2. Create and push annotated release tag:

```bash
git tag -a v0.12.3 -m "Patch Release"
git push origin v0.12.3
```

3. Create draft GitHub release and upload artifacts:
   - `dist/Frame-v0.12.3.zip`
   - `dist/checksums.txt`

4. Regenerate cask for that release version:

```bash
just release-cask 0.12.3
```

5. Copy cask into your tap repo and commit/push:

```bash
cp dist/frame.rb "$FRAME_HOMEBREW_TAP_DIR/Casks/frame.rb"
cd "$FRAME_HOMEBREW_TAP_DIR"
git add Casks/frame.rb
git commit -m "frame 0.12.3"
git push
```

## Rollback/retry notes

- If build fails, fix and re-run `just release-build <version>`.
- If tag push failed partially, clean up the local/remote tag before retrying.
- If cask output looks wrong, regenerate with `just release-cask ...` and re-copy.
