import Common

@MainActor private var lastKnownNativeFocusedWindowId: FrameWindowId? = nil

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromPlatform, syncFocusFromPlatform
@MainActor func updateFocusCache(_ nativeFocused: NativeFocusedWindowSnapshot?) {
    nativeFocused?.app.setLastNativeFocusedWindowId(nativeFocused?.platformWindowId)

    guard let nativeFocused else { return }
    guard let logicalWindow = Window.get(byPlatformWindowId: nativeFocused.platformWindowId) else { return }
    if logicalWindow.parent is ExcludedWindowsContainer {
        return
    }
    if logicalWindow.windowId != lastKnownNativeFocusedWindowId {
        _ = logicalWindow.focusWindow()
        lastKnownNativeFocusedWindowId = logicalWindow.windowId
    }
}

@MainActor
package func resetLastKnownNativeFocusedWindowIdForTests() {
    lastKnownNativeFocusedWindowId = nil
}
