@MainActor private var lastKnownNativeFocusedWindowId: UInt32? = nil

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromPlatform, syncFocusFromPlatform
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is PopupWindowsContainer {
        return
    }
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        _ = nativeFocused?.focusWindow()
        lastKnownNativeFocusedWindowId = nativeFocused?.windowId
    }
    nativeFocused?.app.setLastNativeFocusedWindowId(nativeFocused?.windowId)
}
