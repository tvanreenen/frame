# AX Dump Fixtures

This folder contains AX (Accessibility API) snapshots used by `AxWindowKindTest`.

Each `*.json5` file is a focused-window dump with expected classification fields:

- `Aero.AxUiElementWindowType` (`window`, `dialog`, or `popup`)
- `Aero.AxUiElementWindowType_isDialogHeuristic` (`true` or `false`)

## Manage Fixtures

List fixtures:

```bash
./script/dev/axdump-fixtures.sh list
```

Capture a new fixture from the currently focused window:

```bash
./script/dev/axdump-fixtures.sh capture <name> <window|dialog|popup> <true|false>
```

Example:

```bash
./script/dev/axdump-fixtures.sh capture chrome_share_popup popup true
```

Rename/remove fixtures:

```bash
./script/dev/axdump-fixtures.sh rename <old-name> <new-name>
./script/dev/axdump-fixtures.sh remove <name>
```

Run only fixture classification tests:

```bash
./script/dev/axdump-fixtures.sh check
```

Notes:

- `<name>` can include subdirectories (for scenario grouping), for example
  `scenario_firefox_google_meet_share_window/08_firefox_prompt`.
- `--overwrite` is available via the raw script when you intentionally want to replace a fixture:
  `./script/dev/axdump-fixtures.sh capture <name> <type> <bool> --overwrite`.
