# Frame

Frame is a keyboard-first window and workspace manager for macOS built to make window management simple and intuitive.

![Frame hero](.github/assets/hero.png)

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

## Configuration

Frame works without a user config file on first launch. Create `~/.frame.toml` only if you want to customize the defaults:

```bash
cp docs/config-examples/default-config.toml ~/.frame.toml
```

### Common Customizations

Startup behavior example (`~/.frame.toml`):

```toml
start-at-login = true
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

Gaps: set `inner.*` / `outer.*` to a number, or use an array to tailor per monitor — list `{ monitor."<description>" = <value> }` entries then the default as the last element (descriptions: `main`, `secondary`, numeric order, or a substring of the display name). Example — MacBook built-in (notch) with no top gap, external monitor (e.g. Mac mini) with 32px top gap:

```toml
[gaps]
inner.horizontal = 0
inner.vertical = 0
outer.left = 0
outer.bottom = 0
outer.top = [{ monitor."Built-in Retina Display" = 0 }, 32]
outer.right = 0
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

If Frame misclassifies a specific window, you can force it to be either:

- `tiling`: managed in the normal workspace tile layout
- `excluded`: kept out of the tiled workspace layout entirely

Excluded windows are not workspace-local tiles. They are left out of normal tiling and can remain visible across workspace switches.

Rules are first-match-wins:

```toml
[[window-classification-override]]
if.window-title-regex-substring = "picture-in-picture"
kind = "excluded"
```

Use `if.app-id` for exact app matches, `if.app-name-regex-substring` when the bundle id is inconvenient or unknown, and `if.window-title-regex-substring` for specific transient windows like picture-in-picture. Each rule must define at least one matcher and a `kind`.

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
