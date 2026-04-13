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

private enum WindowClassificationReason: String {
    case nonNormalLevelPopup = "non_normal_level_popup"
    case officeButtonlessPopup = "office_buttonless_popup"
    case ghosttyQuickTerminal = "ghostty_quick_terminal"
    case xcodeOpenQuickly = "xcode_open_quickly"
    case itermNoFullscreen = "iterm_without_fullscreen_button"
    case accessoryWindowWithoutCloseButton = "accessory_window_without_close_button"
    case firefoxWindowSignals = "firefox_window_signals"
    case buttonlessUntitledPopup = "buttonless_untitled_popup"
    case standardWindowLikeSubrole = "standard_window_like_subrole"
    case unsupportedSubrolePopup = "unsupported_subrole_popup"
    case onePasswordNonNormalDialog = "onepassword_non_normal_dialog"
    case iPhoneSimulatorDialog = "iphone_simulator_dialog"
    case nonStandardSubroleDialog = "non_standard_subrole_dialog"
    case firefoxDisabledMinimizeDialog = "firefox_disabled_minimize_dialog"
    case photoBoothDialog = "photobooth_dialog"
    case ghosttyDialog = "ghostty_dialog"
    case noFullscreenDialog = "no_fullscreen_dialog"
}

private enum WindowShapeDecision {
    case popup(WindowClassificationReason)
    case window(WindowClassificationReason)
}

package enum WindowClassifier {
    package static func classify(_ facts: WindowFacts) -> WindowPlacementDecision {
        switch classifyShape(facts) {
            case .popup(let reason):
                return WindowPlacementDecision(
                    placementKind: .excluded,
                    reason: reason.rawValue,
                    debugInfo: facts.debugInfo,
                )
            case .window(let reason):
                if let dialogReason = dialogReason(for: facts) {
                    return WindowPlacementDecision(
                        placementKind: .excluded,
                        reason: dialogReason.rawValue,
                        debugInfo: facts.debugInfo,
                    )
                }
                return WindowPlacementDecision(
                    placementKind: .tiling,
                    reason: reason.rawValue,
                    debugInfo: facts.debugInfo,
                )
        }
    }

    package static func axWindowType(_ facts: WindowFacts) -> AxUiElementWindowType {
        switch classifyShape(facts) {
            case .popup:
                return .popup
            case .window:
                return dialogReason(for: facts) == nil ? .window : .dialog
        }
    }

    package static func isDialog(_ facts: WindowFacts) -> Bool {
        dialogReason(for: facts) != nil
    }

    private static func classifyShape(_ facts: WindowFacts) -> WindowShapeDecision {
        if shouldRejectNonNormalLevelWindow(facts) {
            return .popup(.nonNormalLevelPopup)
        }
        if isMicrosoftOfficePopup(facts) {
            return .popup(.officeButtonlessPopup)
        }
        if facts.knownBundleId == .ghostty && facts.identifier == "com.mitchellh.ghostty.quickTerminal" {
            return .popup(.ghosttyQuickTerminal)
        }
        if facts.knownBundleId == .xcode && facts.identifier == "open_quickly" {
            return .popup(.xcodeOpenQuickly)
        }
        if facts.knownBundleId == .iterm2 && !facts.hasFullscreenButton {
            return .popup(.itermNoFullscreen)
        }
        if facts.activationPolicy == .accessory && !facts.hasCloseButton && facts.knownBundleId != .steam {
            return .popup(.accessoryWindowWithoutCloseButton)
        }

        if facts.knownBundleId?.isFirefox == true {
            if facts.hasAnyStandardWindowControls ||
                facts.isFocused == true ||
                facts.isMain == true ||
                facts.matchesFocusedWindow ||
                facts.subrole == kAXStandardWindowSubrole
            {
                return .window(.firefoxWindowSignals)
            }
            return .popup(.buttonlessUntitledPopup)
        }

        if facts.isButtonless &&
            facts.isFocused != true &&
            facts.isMain != true &&
            !facts.matchesFocusedWindow &&
            facts.subrole != kAXStandardWindowSubrole &&
            ((facts.title ?? "").isEmpty || facts.title == "Window")
        {
            return .popup(.buttonlessUntitledPopup)
        }

        if facts.isStandardWindowLike {
            return .window(.standardWindowLikeSubrole)
        }

        return .popup(.unsupportedSubrolePopup)
    }

    private static func dialogReason(for facts: WindowFacts) -> WindowClassificationReason? {
        if facts.knownBundleId == ._1password && facts.windowLevel != .normalWindow {
            return .onePasswordNonNormalDialog
        }
        if facts.knownBundleId == .iphonesimulator {
            return .iPhoneSimulatorDialog
        }
        if facts.subrole != kAXStandardWindowSubrole && facts.knownBundleId != .qutebrowser {
            return .nonStandardSubroleDialog
        }
        if facts.knownBundleId?.isFirefox == true && facts.isMinimizeButtonEnabled != true {
            return .firefoxDisabledMinimizeDialog
        }
        if facts.knownBundleId == .photoBooth {
            return .photoBoothDialog
        }

        if facts.knownBundleId == .ghostty,
           facts.isFullscreenButtonEnabled != true,
           facts.isCloseButtonEnabled == true
        {
            return .ghosttyDialog
        }

        if facts.isFullscreenButtonEnabled == true {
            return nil
        }
        if facts.knownBundleId?.isVscode == true {
            return nil
        }
        if facts.knownBundleId.map({ noFullscreenDialogExemptIds.contains($0) }) == true {
            return nil
        }
        return .noFullscreenDialog
    }

    private static func shouldRejectNonNormalLevelWindow(_ facts: WindowFacts) -> Bool {
        guard facts.windowLevel != .normalWindow else { return false }
        return facts.knownBundleId?.isFirefox == true ||
            facts.knownBundleId.map { nonNormalWindowPopupIds.contains($0) } == true
    }

    private static func isMicrosoftOfficePopup(_ facts: WindowFacts) -> Bool {
        facts.knownBundleId?.isMicrosoftOfficeApp == true && facts.isButtonless
    }
}
