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
- `dist/frame.rb`
- `dist/checksums.txt`

Build intermediates are created in a temporary work directory and removed automatically.

## Notarization (planned)

Notarization is not yet automated in `just release-build`.

When added, it should run after signing/validation and before zipping/cask generation:

1. Submit the staged app bundle and CLI binary to Apple notarization.
2. Wait for notarization success.
3. Staple the notarization ticket to the staged app bundle.
4. Then package `dist/Frame-v<version>.zip` and generate `dist/frame.rb`.

## Generate cask manually

```bash
just release-cask <version> <zip_or_url>
```

Examples:

```bash
just release-cask 0.12.3 ./dist/Frame-v0.12.3.zip
```

## Publish flow helper (interactive)

```bash
just release-publish <version> <cask_repo_path>
```

Example:

```bash
just release-publish 0.12.3 ~/Code/homebrew-tap
```

The helper:

1. Runs checks
2. Builds release artifacts
3. Creates/pushes git tag
4. Opens release page and zip in Finder
5. Regenerates and copies cask to the tap repo

## Rollback/retry notes

- If build fails, fix and re-run `just release-build <version>`.
- If tag push failed partially, clean up the local/remote tag before retrying.
- If cask output looks wrong, regenerate with `just release-cask ...` and re-copy.
