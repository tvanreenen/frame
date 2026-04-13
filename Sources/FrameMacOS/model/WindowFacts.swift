import AppKit
import FrameEngine

package struct WindowFacts: Equatable, Sendable {
    package let appId: String?
    package let knownBundleId: KnownBundleId?
    package let windowId: UInt32
    package let title: String?
    package let role: String?
    package let subrole: String?
    package let identifier: String?
    package let isFocused: Bool?
    package let isMain: Bool?
    package let isModal: Bool?
    package let isMinimized: Bool?
    package let isFullscreen: Bool?
    package let matchesMainWindow: Bool
    package let matchesFocusedWindow: Bool
    package let windowLevel: MacOsWindowLevel?
    package let activationPolicy: NSApplication.ActivationPolicy
    package let hasCloseButton: Bool
    package let hasMinimizeButton: Bool
    package let hasZoomButton: Bool
    package let hasFullscreenButton: Bool
    package let isCloseButtonEnabled: Bool?
    package let isMinimizeButtonEnabled: Bool?
    package let isZoomButtonEnabled: Bool?
    package let isFullscreenButtonEnabled: Bool?

    package var hasAnyStandardWindowControls: Bool {
        hasCloseButton || hasMinimizeButton || hasZoomButton || hasFullscreenButton
    }

    package var isButtonless: Bool { !hasAnyStandardWindowControls }

    package var isPrimaryAppWindow: Bool {
        matchesMainWindow || matchesFocusedWindow || isMain == true || isFocused == true
    }

    package var isStandardWindowLike: Bool {
        subrole == kAXStandardWindowSubrole ||
            subrole == kAXDialogSubrole ||
            subrole == kAXFloatingWindowSubrole ||
            (knownBundleId == .finder && subrole == "Quick Look")
    }

    package init(
        appId: String?,
        knownBundleId: KnownBundleId?,
        windowId: UInt32,
        title: String?,
        role: String?,
        subrole: String?,
        identifier: String?,
        isFocused: Bool?,
        isMain: Bool?,
        isModal: Bool?,
        isMinimized: Bool?,
        isFullscreen: Bool?,
        matchesMainWindow: Bool,
        matchesFocusedWindow: Bool,
        windowLevel: MacOsWindowLevel?,
        activationPolicy: NSApplication.ActivationPolicy,
        hasCloseButton: Bool,
        hasMinimizeButton: Bool,
        hasZoomButton: Bool,
        hasFullscreenButton: Bool,
        isCloseButtonEnabled: Bool?,
        isMinimizeButtonEnabled: Bool?,
        isZoomButtonEnabled: Bool?,
        isFullscreenButtonEnabled: Bool?,
    ) {
        self.appId = appId
        self.knownBundleId = knownBundleId
        self.windowId = windowId
        self.title = title
        self.role = role
        self.subrole = subrole
        self.identifier = identifier
        self.isFocused = isFocused
        self.isMain = isMain
        self.isModal = isModal
        self.isMinimized = isMinimized
        self.isFullscreen = isFullscreen
        self.matchesMainWindow = matchesMainWindow
        self.matchesFocusedWindow = matchesFocusedWindow
        self.windowLevel = windowLevel
        self.activationPolicy = activationPolicy
        self.hasCloseButton = hasCloseButton
        self.hasMinimizeButton = hasMinimizeButton
        self.hasZoomButton = hasZoomButton
        self.hasFullscreenButton = hasFullscreenButton
        self.isCloseButtonEnabled = isCloseButtonEnabled
        self.isMinimizeButtonEnabled = isMinimizeButtonEnabled
        self.isZoomButtonEnabled = isZoomButtonEnabled
        self.isFullscreenButtonEnabled = isFullscreenButtonEnabled
    }

    package var debugInfo: WindowClassificationDebugInfo {
        WindowClassificationDebugInfo(
            appId: appId,
            windowId: windowId,
            title: title,
            role: role,
            subrole: subrole,
            identifier: identifier,
            isFocused: isFocused,
            isMain: isMain,
            isModal: isModal,
            isMinimized: isMinimized,
            isFullscreen: isFullscreen,
            matchesMainWindow: matchesMainWindow,
            matchesFocusedWindow: matchesFocusedWindow,
            windowLevel: windowLevel?.debugDescription,
            activationPolicy: activationPolicy.debugDescription,
            hasCloseButton: hasCloseButton,
            hasMinimizeButton: hasMinimizeButton,
            hasZoomButton: hasZoomButton,
            hasFullscreenButton: hasFullscreenButton,
            isCloseButtonEnabled: isCloseButtonEnabled,
            isMinimizeButtonEnabled: isMinimizeButtonEnabled,
            isZoomButtonEnabled: isZoomButtonEnabled,
            isFullscreenButtonEnabled: isFullscreenButtonEnabled,
            hasAnyStandardWindowControls: hasAnyStandardWindowControls,
            isButtonless: isButtonless,
            isPrimaryAppWindow: isPrimaryAppWindow,
            isStandardWindowLike: isStandardWindowLike,
        )
    }
}

extension NSApplication.ActivationPolicy {
    fileprivate var debugDescription: String {
        switch self {
            case .regular: "regular"
            case .accessory: "accessory"
            case .prohibited: "prohibited"
            @unknown default: "unknown"
        }
    }
}

extension MacOsWindowLevel {
    fileprivate var debugDescription: String {
        switch self {
            case .normalWindow: "normalWindow"
            case .alwaysOnTopWindow: "alwaysOnTopWindow"
            case .unknown(let windowLevel): "unknown(\(windowLevel))"
        }
    }
}
