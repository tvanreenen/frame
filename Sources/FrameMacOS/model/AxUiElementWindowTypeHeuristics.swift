import AppKit
import FrameEngine

private let nonNormalWindowPopupIds: Set<KnownBundleId> = [
    .slack,
    .chrome,
    .braveBrowser,
    .screenstudio,
    .cleanshotx,
    .iterm2,
]

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

extension AxUiElementMock {
    func isDialogHeuristic(_ id: KnownBundleId?, _ windowLevel: MacOsWindowLevel?) -> Bool {
        if id == ._1password && windowLevel != .normalWindow { return true }
        if id == .iphonesimulator { return true }
        if get(Ax.subroleAttr) != kAXStandardWindowSubrole && id != .qutebrowser { return true }
        if id?.isFirefox == true && get(Ax.minimizeButtonAttr)?.get(Ax.enabledAttr) != true { return true }
        if id == .photoBooth { return true }

        if id == .ghostty {
            return get(Ax.fullscreenButtonAttr)?.get(Ax.enabledAttr) != true &&
                get(Ax.closeButtonAttr)?.get(Ax.enabledAttr) == true
        }

        return shouldTreatNoFullscreenAsDialog(id)
    }

    func isWindowHeuristic(
        axApp: AxUiElementMock,
        _ id: KnownBundleId?,
        _ activationPolicy: NSApplication.ActivationPolicy,
        _ windowLevel: MacOsWindowLevel?,
    ) -> Bool {
        if shouldRejectNonNormalLevelWindow(id, windowLevel) { return false }
        if id == .ghostty && get(Ax.identifierAttr) == "com.mitchellh.ghostty.quickTerminal" { return false }

        lazy var fullscreenButton = get(Ax.fullscreenButtonAttr)

        if id == .xcode && get(Ax.identifierAttr) == "open_quickly" { return false }
        if id == .iterm2 && fullscreenButton == nil { return false }
        if activationPolicy == .accessory && get(Ax.closeButtonAttr) == nil && id != .steam { return false }

        if id?.isFirefox != true {
            return isWindowHeuristicOld(axApp: axApp, id)
        }

        return get(Ax.closeButtonAttr) != nil ||
            fullscreenButton != nil ||
            get(Ax.zoomButtonAttr) != nil ||
            get(Ax.minimizeButtonAttr) != nil ||
            get(Ax.isFocused) == true ||
            get(Ax.isMainAttr) == true ||
            axApp.get(Ax.focusedWindowAttr)?.windowId == self.containingWindowId() ||
            get(Ax.subroleAttr) == kAXStandardWindowSubrole
    }

    private func isWindowHeuristicOld(axApp: AxUiElementMock, _ id: KnownBundleId?) -> Bool {
        lazy var subrole = get(Ax.subroleAttr)
        lazy var title = get(Ax.titleAttr) ?? ""

        if get(Ax.closeButtonAttr) == nil &&
            get(Ax.fullscreenButtonAttr) == nil &&
            get(Ax.zoomButtonAttr) == nil &&
            get(Ax.minimizeButtonAttr) == nil &&
            get(Ax.isFocused) == false &&
            get(Ax.isMainAttr) == false &&
            axApp.get(Ax.focusedWindowAttr)?.windowId != containingWindowId() &&
            subrole != kAXStandardWindowSubrole &&
            (title.isEmpty || title == "Window")
        {
            return false
        }
        return subrole == kAXStandardWindowSubrole ||
            subrole == kAXDialogSubrole ||
            subrole == kAXFloatingWindowSubrole ||
            id == .finder && subrole == "Quick Look"
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
        if id?.isVscode == true { return false }
        return !(id.map { noFullscreenDialogExemptIds.contains($0) } ?? false)
    }
}
