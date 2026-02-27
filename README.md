# Simple Window Manager (simple-wm)

simple-wm is a window manager for macOS forked from the popular AeroSpace tiling window manager. The main goal was two fold: simplify the mental model of mananging windows and simplify the code.

---

> [!NOTE]
> A new README is still in progress. Below are some assorted things I left until I can incorporate them appropirately.

In multi-monitor setup please make sure that monitors [are properly arranged](https://nikitabobko.github.io/AeroSpace/guide#proper-monitor-arrangement).

By using AeroSpace, you acknowledge that it's not [notarized](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution). Notarization is a "security" feature by Apple. You send binaries to Apple, and they either approve them or not. We'll see where we go with this.

[Homebrew installation script](https://github.com/nikitabobko/homebrew-tap/blob/main/Casks/aerospace.rb) is configured to automatically delete `com.apple.quarantine` attribute, that's why the app should work out of the box, without any warnings that "Apple cannot check AeroSpace for malicious software".

|                                                                                | macOS 13 (Ventura) | macOS 14 (Sonoma) | macOS 15 (Sequoia) | macOS 26 (Tahoe) |
| ------------------------------------------------------------------------------ | ------------------ | ----------------- | ------------------ | ---------------- |
| AeroSpace binary runs on ...                                                   | +                  | +                 | +                  | +                |
| AeroSpace debug build from sources is supported on ...                         |                    | +                 | +                  | +                |
| AeroSpace release build from sources is supported on ... (Requires Xcode 26+)  |                    |                   | +                  | +                |


```bash
defaults write -g NSWindowShouldDragOnGesture -bool true
```

With this command, you can move windows by holding `ctrl`+`cmd` and dragging any part of the window (not necessarily the window title)

Source: [reddit](https://www.reddit.com/r/MacOS/comments/k6hiwk/keyboard_modifier_to_simplify_click_drag_of/)

