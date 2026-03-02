# Development

`just` is the canonical interface for local development tasks.

## Prerequisites

- macOS 13+ (project target)
- Xcode (for SDK/toolchain and release builds)
- `swift`
- `just`
- Homebrew tools from `Brewfile`

Run once:

```bash
just setup
```

Optional tools:

- `xcbeautify` (prettier Xcode logs)

## Day-to-day commands

- Build debug app: `just build`
- Run debug app: `just run`
- Run unit tests only: `just test`
- Run CLI smoke checks only: `just smoke`
- Format/lint with fixes: `just fmt`
- Normal pre-commit checks: `just check`
- Clean local Xcode/derived artifacts: `just clean`

`just check` runs unit tests + CLI smoke checks + non-mutating format/lint verification.

## Typical loop

1. Build app with `just build`
2. Launch app with `just run`
3. Make code changes
4. Run `just test`
5. Before commit, run `just check`

## Accessibility reset helper

When permission state gets out of sync:

```bash
just reset-accessibility
```

Then relaunch the app with `just run`.

## AX dump fixtures (window classification regression tests)

AX fixtures live in:

- `Sources/AppBundleTests/fixtures/axDumps`

Useful commands:

- List fixtures: `./script/dev/axdump-fixtures.sh list`
- Capture focused window fixture: `./script/dev/axdump-fixtures.sh capture <name> <window|dialog|popup> <true|false>`
- Rename fixture: `./script/dev/axdump-fixtures.sh rename <old-name> <new-name>`
- Remove fixture: `./script/dev/axdump-fixtures.sh remove <name>`
- Run only classification fixture tests: `./script/dev/axdump-fixtures.sh check`

Example:

```bash
./script/dev/axdump-fixtures.sh capture firefox_google_meet_share_popup popup true
./script/dev/axdump-fixtures.sh check
```

## Notes

- Legacy wrapper scripts are intentionally removed.
- Core build/release plumbing scripts still exist, but `just` is the supported entrypoint.
