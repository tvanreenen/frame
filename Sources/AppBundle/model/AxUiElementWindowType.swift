import AppKit

enum AxUiElementWindowType: String {
    case window
    case dialog
    /// Not even a real window
    case popup

    static func new(isWindow: Bool, isDialog: () -> Bool) -> AxUiElementWindowType {
        switch true {
            case !isWindow: .popup
            case isDialog(): .dialog
            default: .window
        }
    }
}

// Slowly roll out window-level based popup filtering only for apps with reliable dumps.
private let nonNormalWindowPopupIds: Set<KnownBundleId> = [
    .slack,
    .chrome,
    .braveBrowser,
    .screenstudio,
    .cleanshotx,
    .iterm2,
]

// These apps can intentionally hide/disable fullscreen controls for normal windows.
private let noFullscreenDialogExemptIds: Set<KnownBundleId> = [
    .gimp,
    .chrome,
    .activityMonitor,
    .alacritty,
    .kitty,
    .wezterm,
    .qutebrowser,
    .iterm2,
    .emacs,
    .steam,
]

// Covered by fixtures in Sources/AppBundleTests/fixtures/axDumps
extension AxUiElementMock {
    // 'isDialogHeuristic' function name is referenced in the guide
    func isDialogHeuristic(
        _ id: KnownBundleId?,
        _ windowLevel: MacOsWindowLevel?,
    ) -> Bool {
        // Note: a lot of windows don't have title on startup. So please don't rely on the title
        if id == ._1password && windowLevel != .normalWindow { return true }
        if id == .iphonesimulator { return true }

        // Minimized windows or windows of a hidden app have subrole "AXDialog".
        // qutebrowser regular windows can also use AXDialog when decorations are disabled.
        if get(Ax.subroleAttr) != kAXStandardWindowSubrole && id != .qutebrowser { return true }

        // Firefox: Picture in Picture window doesn't have minimize button.
        // todo. bug: when firefox shows non-native fullscreen, minimize button is disabled for all other non-fullscreen windows
        if id?.isFirefox == true && get(Ax.minimizeButtonAttr)?.get(Ax.enabledAttr) != true { return true }
        if id == .photoBooth { return true }

        if id == .ghostty {
            return get(Ax.fullscreenButtonAttr)?.get(Ax.enabledAttr) != true &&
                get(Ax.closeButtonAttr)?.get(Ax.enabledAttr) == true
        }

        // Float windows without fullscreen control unless the app is known to hide it for regular windows.
        return shouldTreatNoFullscreenAsDialog(id)
    }

    /// Alternative name: !isPopup
    ///
    /// Why do we need to filter out non-windows?
    /// - "floating by default" workflow
    /// - It's annoying that the focus command treats these popups as floating windows
    func isWindowHeuristic(
        axApp: AxUiElementMock,
        _ id: KnownBundleId?,
        _ activationPolicy: NSApplication.ActivationPolicy,
        _ windowLevel: MacOsWindowLevel?,
    ) -> Bool {
        if shouldRejectNonNormalLevelWindow(id, windowLevel) { return false }

        // Just don't do anything with "Ghostty Quick Terminal" windows.
        // Its position and size are managed by the Ghostty itself
        // https://github.com/tvanreenen/frame/issues/103
        // https://github.com/ghostty-org/ghostty/discussions/3512
        if id == .ghostty && get(Ax.identifierAttr) == "com.mitchellh.ghostty.quickTerminal" { return false }

        lazy var fullscreenButton = get(Ax.fullscreenButtonAttr)

        if id == .xcode && get(Ax.identifierAttr) == "open_quickly" { return false }
        if id == .iterm2 && fullscreenButton == nil { return false }

        if activationPolicy == .accessory && get(Ax.closeButtonAttr) == nil && id != .steam { return false }

        if id?.isFirefox != true {
            return isWindowHeuristicOld(axApp: axApp, id)
        }

        // Try to filter out incredibly weird popup like AXWindows without any buttons.
        // E.g.
        // - Sonoma (macOS 14) keyboard layout switch (AXSubrole == AXDialog)
        // - IntelliJ context menu (right mouse click)
        // - Telegram context menu (right mouse click)
        // - Share window purple "pill" indicator https://github.com/tvanreenen/frame/issues/1101. Title is not empty
        // - Tooltips on links mouse hover in browsers (Chrome, Firefox)
        // - Tooltips on buttons (e.g. new tab, Extensions) mouse hover in browsers (Chrome, Firefox). Title is not empty
        // Make sure that the following AXWindow remain windows:
        // - macOS native file picker ("Open..." menu) (subrole == kAXDialogSubrole)
        // - telegram image viewer (subrole == kAXFloatingWindowSubrole)
        // - Finder preview (hit space) (subrole == "Quick Look")
        // - Firefox non-native video fullscreen (about:config -> full-screen-api.macos-native-full-screen -> false, subrole == AXUnknown)
        return get(Ax.closeButtonAttr) != nil ||
            fullscreenButton != nil ||
            get(Ax.zoomButtonAttr) != nil ||
            get(Ax.minimizeButtonAttr) != nil ||

            get(Ax.isFocused) == true ||  // 3 different ways to detect if the window is focused
            get(Ax.isMainAttr) == true ||
            axApp.get(Ax.focusedWindowAttr)?.windowId == self.containingWindowId() ||

            get(Ax.subroleAttr) == kAXStandardWindowSubrole
    }

    private func isWindowHeuristicOld(axApp: AxUiElementMock, _ id: KnownBundleId?) -> Bool { // 0.18.3 hotfix
        lazy var subrole = get(Ax.subroleAttr)
        lazy var title = get(Ax.titleAttr) ?? ""

        // Try to filter out incredibly weird popup like AXWindows without any buttons.
        // E.g.
        // - Sonoma (macOS 14) keyboard layout switch
        // - IntelliJ context menu (right mouse click)
        // - Telegram context menu (right mouse click)
        if get(Ax.closeButtonAttr) == nil &&
            get(Ax.fullscreenButtonAttr) == nil &&
            get(Ax.zoomButtonAttr) == nil &&
            get(Ax.minimizeButtonAttr) == nil &&

            get(Ax.isFocused) == false &&  // Three different ways to detect if the window is not focused
            get(Ax.isMainAttr) == false &&
            axApp.get(Ax.focusedWindowAttr)?.windowId != containingWindowId() &&

            subrole != kAXStandardWindowSubrole &&
            // Share window purple "pill" indicator has "Window" title https://github.com/tvanreenen/frame/issues/1101
            (title.isEmpty || title == "Window") // Maybe it doesn't work in non-English locale
        {
            return false
        }
        return subrole == kAXStandardWindowSubrole ||
            subrole == kAXDialogSubrole || // macOS native file picker ("Open..." menu) (kAXDialogSubrole value)
            subrole == kAXFloatingWindowSubrole || // telegram image viewer
            id == .finder && subrole == "Quick Look" // Finder preview (hit space) is a floating window
    }

    func getWindowType(
        axApp: AxUiElementMock,
        _ id: KnownBundleId?,
        _ activationPolicy: NSApplication.ActivationPolicy,
        _ windowLevel: MacOsWindowLevel?,
    ) -> AxUiElementWindowType {
        .new(
            isWindow: isWindowHeuristic(axApp: axApp, id, activationPolicy, windowLevel),
            isDialog: { isDialogHeuristic(id, windowLevel) },
        )
    }

    private func shouldRejectNonNormalLevelWindow(_ id: KnownBundleId?, _ windowLevel: MacOsWindowLevel?) -> Bool {
        guard windowLevel != .normalWindow else { return false }
        return id?.isFirefox == true || (id.map { nonNormalWindowPopupIds.contains($0) } ?? false)
    }

    private func shouldTreatNoFullscreenAsDialog(_ id: KnownBundleId?) -> Bool {
        guard get(Ax.fullscreenButtonAttr)?.get(Ax.enabledAttr) != true else { return false }
        if id?.isVscode == true { return false } // "window.nativeFullScreen": false
        return !(id.map { noFullscreenDialogExemptIds.contains($0) } ?? false)
    }
}
