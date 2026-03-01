# Frame

Frame is a keyboard-first window manager for macOS built to make window management simple and intuitive.

It focuses on layout and navigation — automatically organizing windows to fill the available screen space with no overlapping or layering. Keyboard shortcuts provide deliberate control over navigating, resizing, and movement within and across workspaces, while native macOS window behavior remains intact.

---

## Install

```bash
brew tap tvanreenen/tap
brew install --cask frame
```

## Default Keybindings

The defaults are intentionally layered so the same keys keep the same meaning:

- `alt + h/j/k/l`: focus left/down/up/right
- `alt + shift + h/j/k/l`: move the focused window left/down/up/right
- `ctrl + shift + alt + h/j/k/l`: resize the focused window
- `alt + 1..0`: switch workspace
- `alt + shift + 1..0`: move focused window to workspace
- `alt + f`: toggle fullscreen

The pattern is consistent: keep the direction or number key, then add modifiers for a stronger variant of the same intent (focus -> move/resize, workspace switch -> move window to workspace).

## Single vs Dual Monitor Setup

The default config is monitor-agnostic and works out of the box for both single and multi-monitor setups.

- `on-focused-monitor-changed = ['move-mouse monitor-lazy-center']` keeps pointer/focus behavior natural when changing monitors.
- Workspaces are not pinned by default, so they can be used on whichever monitor is active.

`workspace-to-monitor-force-assignment` supports monitor selectors:

- `main`: the macOS primary display (not necessarily left)
- `secondary`: the non-primary display in a 2-monitor setup
- `1`, `2`, ...: monitor sequence numbers ordered left-to-right

Single-monitor example (`~/.frame.toml`):

```toml
[workspace-to-monitor-force-assignment]
1 = "main"
2 = "main"
3 = "main"
4 = "main"
5 = "main"
6 = "main"
7 = "main"
8 = "main"
9 = "main"
0 = "main"
```

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

Here, monitor `1` is the left display and monitor `2` is the right display (sequence numbers are ordered left-to-right).

If your primary monitor is on the right, the same split can also be written with semantic names:

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

## Workspace Change Hook (SketchyBar, etc.)

`exec-on-workspace-change` is supported and runs a process whenever focused workspace changes. The callback environment includes:

- `FRAME_FOCUSED_WORKSPACE`
- `FRAME_PREV_WORKSPACE`

Example:

```toml
exec-on-workspace-change = ['/bin/bash', '-c', 'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$FRAME_FOCUSED_WORKSPACE']
```
