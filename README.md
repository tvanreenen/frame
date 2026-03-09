# Frame

Frame is a keyboard-first window manager for macOS built to make window management simple and intuitive.

![Frame icon](./resources/Assets.xcassets/AppIcon.appiconset/Frame-macOS-Default-128x128@1x.png)

It focuses on layout and navigation — automatically organizing windows to fill the available screen space with no overlapping or layering. Keyboard shortcuts provide deliberate control over navigating, resizing, and movement within and across workspaces, while native macOS window behavior remains intact.

---

## Install

```bash
brew tap tvanreenen/tap
brew install --cask frame
```

## App and CLI

Frame installs both a menu bar app and a CLI:

- `Frame.app` runs in the background, manages your windows, and handles key bindings
- `frame` is the command-line client for querying state, running actions, and scripting Frame

Most people will interact with Frame through key bindings and the menu bar app. The CLI is there when you want automation, shell integration, or quick inspection from the terminal.
On first launch, open `Frame.app` and grant Accessibility access if macOS prompts for it.

## Quick Start

Learn the core defaults:

- `alt + h/j/k/l`: focus left/down/up/right
- `alt + shift + h/j/k/l`: move the focused window left/down/up/right
- `ctrl + shift + alt + h/j/k/l`: resize the focused window
- `alt + 1..0`: switch workspace
- `alt + shift + 1..0`: move focused window to workspace
- `alt + f`: toggle fullscreen

These are intentionally layered: keep direction/number keys the same, add modifiers for stronger variants (focus -> move/resize, workspace -> move-to-workspace).

### Verify Install

```bash
frame --version
```

CLI version output:

- `<version+hash>`

For CLI + daemon diagnostics:

```bash
frame doctor
```

## Configuration

Frame works without a user config file on first launch. Create `~/.frame.toml` only if you want to customize the defaults:

```bash
cp docs/config-examples/default-config.toml ~/.frame.toml
```

### Common Customizations

Startup behavior example (`~/.frame.toml`):

```toml
start-at-login = false
```

Persistent workspaces keep named workspaces alive even when empty, so they remain addressable and stable for keybindings/status bars:

```toml
persistent-workspaces = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
```

Keybinding config example (`~/.frame.toml`):

```toml
[binding]
alt-h = "focus left"
alt-j = "focus down"
alt-k = "focus up"
alt-l = "focus right"

alt-shift-h = "move left"
alt-shift-j = "move down"
alt-shift-k = "move up"
alt-shift-l = "move right"

ctrl-shift-alt-h = "resize width -50"
ctrl-shift-alt-l = "resize width +50"
ctrl-shift-alt-j = "resize height +50"
ctrl-shift-alt-k = "resize height -50"

alt-1 = "workspace 1"
alt-shift-1 = "move-node-to-workspace 1"
alt-f = "fullscreen"
```

Gaps config example (`~/.frame.toml`):

```toml
[gaps]
inner.horizontal = 8
inner.vertical = 8
outer.left = 8
outer.bottom = 8
outer.top = 8
outer.right = 8
```

### Single vs Dual Monitor Setup

By default, workspaces are monitor-agnostic. You only need monitor config if you want fixed workspace placement.

`workspace-to-monitor-force-assignment` supports:

- `main`
- `secondary`
- numeric monitor order (`1`, `2`, ...)
- regex on monitor names

On a single monitor, you get all workspaces `1-0` without any monitor-assignment config.
The dual-monitor mapping below only takes effect when a second monitor is present.

Dual-monitor example (`~/.frame.toml`) with `1-5` on secondary and `6-0` on main:

```toml
[workspace-to-monitor-force-assignment]
1 = "secondary"
2 = "secondary"
3 = "secondary"
4 = "secondary"
5 = "secondary"
6 = "main"
7 = "main"
8 = "main"
9 = "main"
0 = "main"
```

Simplified alternatives:

```toml
[workspace-to-monitor-force-assignment]
1 = 1               # numeric monitor order
2 = ".*studio.*"    # regex partial monitor name match (case-insensitive)
```

Note: `main` means the macOS primary display (not necessarily left), and `secondary` means the other display in a 2-monitor setup. Regex is matched case-insensitively against each monitor's macOS display name (`NSScreen.localizedName`).

### Workspace Change Hook (SketchyBar, etc.)

`workspace-change-hook` runs a process whenever focused workspace changes. The callback environment injects `FRAME_FOCUSED_WORKSPACE`, includes inherited environment variables, and prepends Homebrew paths (`/opt/homebrew/bin:/opt/homebrew/sbin`) to `PATH`.

If set, `workspace-change-hook` must be a non-empty command array (first element is executable path).

Example:

```toml
workspace-change-hook = ['/bin/bash', '-c', 'sketchybar --trigger frame_workspace_change FOCUSED_WORKSPACE=$FRAME_FOCUSED_WORKSPACE']
```

### Window Classification Overrides (Optional)

If Frame misclassifies a specific app window as `popup`/`dialog`/`window`, you can force a kind with first-match-wins rules:

```toml
[[window-classification-override]]
if.app-id = "com.apple.finder"
kind = "tiling"

[[window-classification-override]]
if.app-name-regex-substring = "slack"
kind = "floating"

[[window-classification-override]]
if.window-title-regex-substring = "picture-in-picture"
kind = "popup"
```

Matcher fields are optional per rule (`app-id`, `app-name-regex-substring`, `window-title-regex-substring`), but each rule must define at least one matcher and a `kind`.

## Troubleshooting

### Config Errors and Recovery

- Config parsing is strict: unknown keys, type mismatches, and invalid values fail validation.
- On startup, if config validation fails, Frame shows a config error and falls back to the built-in default config so it can still run.
- Validate your file directly:

```bash
frame doctor
```

- After fixing your config, apply it with:

```bash
frame reload-config
```

- Error output is grouped by section and includes stable `CFG###` codes to make failures easier to identify and fix.
