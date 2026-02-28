# Frame

Frame is a tiling window manager for macOS. This fork focuses on simplifying both the window-management mental model and the codebase.

---

> [!NOTE]
> A new README is still in progress. Below are some assorted things I left until I can incorporate them appropriately.

In multi-monitor setups, make sure monitors are arranged correctly in macOS display settings.

By using Frame, you acknowledge that it's not [notarized](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution). Notarization is a "security" feature by Apple. You send binaries to Apple, and they either approve them or not. We'll see where we go with this.

[Homebrew installation script](https://github.com/tvanreenen/homebrew-tap/blob/main/Casks/frame.rb) is configured to automatically delete `com.apple.quarantine` attribute, that's why the app should work out of the box, without any warnings that "Apple cannot check Frame for malicious software".

|                                                                   | macOS 13 (Ventura) | macOS 14 (Sonoma) | macOS 15 (Sequoia) | macOS 26 (Tahoe) |
| ----------------------------------------------------------------- | ------------------ | ----------------- | ------------------ | ---------------- |
| Frame binary runs on ...                                          | +                  | +                 | +                  | +                |
| Frame debug build from sources is supported on ...                |                    | +                 | +                  | +                |
| Frame release build from sources is supported on ... (Xcode 26+)  |                    |                   | +                  | +                |


```bash
defaults write -g NSWindowShouldDragOnGesture -bool true
```

With this command, you can move windows by holding `ctrl`+`cmd` and dragging any part of the window (not necessarily the window title)

Source: [reddit](https://www.reddit.com/r/MacOS/comments/k6hiwk/keyboard_modifier_to_simplify_click_drag_of/)
