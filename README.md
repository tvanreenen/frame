# Frame

![Frame icon](./resources/Assets.xcassets/AppIcon.appiconset/Frame-macOS-Default-256x256@1x.png)

Frame is a keyboard-first window manager for macOS built to make window management simple and intuitive.

It focuses on layout and navigation — automatically organizing windows to fill the available screen space with no overlapping or layering. Keyboard shortcuts provide deliberate control over navigating, resizing, and movement within and across workspaces, while native macOS window behavior remains intact.

---

## Install

```bash
brew tap tvanreenen/tap
brew install --cask frame
```

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

If you want to customize settings, start by copying the default config:

```bash
cp docs/config-examples/default-config.toml ~/.frame.toml
```

### Basic Config Ideas

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

`workspace-to-monitor-force-assignment` supports `main`, `secondary`, numeric monitor order (`1`, `2`, ...), and regex on monitor names.

Dual-monitor example (`~/.frame.toml`) with `1-5` on left and `6-0` on right:

```toml
[workspace-to-monitor-force-assignment]
1 = 1
2 = 1
3 = 1
4 = 1
5 = 1
6 = 2
7 = 2
8 = 2
9 = 2
0 = 2
```

Note: `main` means the macOS primary display (not necessarily left), and `secondary` means the other display in a 2-monitor setup. Regex matching is case-insensitive.

### Workspace Change Hook (SketchyBar, etc.)

`exec-on-workspace-change` is supported and runs a process whenever focused workspace changes. The callback environment includes `FRAME_FOCUSED_WORKSPACE`.

Example:

```toml
exec-on-workspace-change = ['/bin/bash', '-c', 'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$FRAME_FOCUSED_WORKSPACE']
```

### Window Classification Overrides (Optional)

If Frame misclassifies a specific app window as `popup`/`dialog`/`window`, you can force a kind with first-match-wins rules:

```toml
[[window-classification-override]]
if.app-id = "com.apple.finder"
kind = "window"

[[window-classification-override]]
if.window-title-regex-substring = "picture-in-picture"
kind = "popup"
```

Matcher fields are optional per rule (`app-id`, `app-name-regex-substring`, `window-title-regex-substring`), but each rule must define at least one matcher and a `kind`.
