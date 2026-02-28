# Development

`just` is the canonical interface for local development tasks.

## Prerequisites

- macOS 13+ (project target)
- Xcode (for SDK/toolchain and release builds)
- `swift` (or `swiftly`, optional but recommended)
- `just`

Optional tools:

- `xcbeautify` (prettier Xcode logs)

## Day-to-day commands

- Run debug app: `just dev`
- Run unit tests only: `just test`
- Format/lint with fixes: `just fmt`
- Normal pre-commit checks: `just check`
- Clean local Xcode/derived artifacts: `just clean`

`just check` runs build + tests + CLI smoke checks + non-mutating format/lint verification.

## Typical loop

1. Start app with `just dev`
2. Make code changes
3. Run `just test`
4. Before commit, run `just check`

## Accessibility reset helper

When debug permission state gets out of sync:

```bash
just reset-accessibility
```

Then relaunch the app with `just dev`.

## Notes

- Legacy wrapper scripts are intentionally removed.
- Core build/release plumbing scripts still exist, but `just` is the supported entrypoint.
