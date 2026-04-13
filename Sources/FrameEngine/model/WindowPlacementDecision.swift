import Foundation

package enum WindowPlacementDecisionSource: String, Equatable, Sendable {
    case cachedAxWindow = "cached_ax_window"
    case focusedWindowLookup = "focused_window_lookup"
    case windowsListLookup = "windows_list_lookup"
    case disappearedBeforeClassification = "disappeared_before_classification"
    case disappearedBeforeRegistration = "disappeared_before_registration"
}

package struct WindowClassificationDebugInfo: Encodable, Equatable, Sendable {
    package var appId: String?
    package var windowId: UInt32
    package var title: String?
    package var role: String?
    package var subrole: String?
    package var identifier: String?
    package var isFocused: Bool?
    package var isMain: Bool?
    package var isModal: Bool?
    package var isMinimized: Bool?
    package var isFullscreen: Bool?
    package var matchesMainWindow: Bool
    package var matchesFocusedWindow: Bool
    package var windowLevel: String?
    package var activationPolicy: String
    package var hasCloseButton: Bool
    package var hasMinimizeButton: Bool
    package var hasZoomButton: Bool
    package var hasFullscreenButton: Bool
    package var isCloseButtonEnabled: Bool?
    package var isMinimizeButtonEnabled: Bool?
    package var isZoomButtonEnabled: Bool?
    package var isFullscreenButtonEnabled: Bool?
    package var hasAnyStandardWindowControls: Bool
    package var isButtonless: Bool
    package var isPrimaryAppWindow: Bool
    package var isStandardWindowLike: Bool

    package init(
        appId: String? = nil,
        windowId: UInt32,
        title: String? = nil,
        role: String? = nil,
        subrole: String? = nil,
        identifier: String? = nil,
        isFocused: Bool? = nil,
        isMain: Bool? = nil,
        isModal: Bool? = nil,
        isMinimized: Bool? = nil,
        isFullscreen: Bool? = nil,
        matchesMainWindow: Bool,
        matchesFocusedWindow: Bool,
        windowLevel: String? = nil,
        activationPolicy: String,
        hasCloseButton: Bool,
        hasMinimizeButton: Bool,
        hasZoomButton: Bool,
        hasFullscreenButton: Bool,
        isCloseButtonEnabled: Bool? = nil,
        isMinimizeButtonEnabled: Bool? = nil,
        isZoomButtonEnabled: Bool? = nil,
        isFullscreenButtonEnabled: Bool? = nil,
        hasAnyStandardWindowControls: Bool,
        isButtonless: Bool,
        isPrimaryAppWindow: Bool,
        isStandardWindowLike: Bool,
    ) {
        self.appId = appId
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
        self.hasAnyStandardWindowControls = hasAnyStandardWindowControls
        self.isButtonless = isButtonless
        self.isPrimaryAppWindow = isPrimaryAppWindow
        self.isStandardWindowLike = isStandardWindowLike
    }
}

package struct WindowPlacementDecision: Equatable, Sendable {
    package var placementKind: WindowPlacementKind
    package var reason: String
    package var source: String?
    package var debugInfo: WindowClassificationDebugInfo?

    package init(
        placementKind: WindowPlacementKind,
        reason: String,
        source: String? = nil,
        debugInfo: WindowClassificationDebugInfo? = nil,
    ) {
        self.placementKind = placementKind
        self.reason = reason
        self.source = source
        self.debugInfo = debugInfo
    }

    package func withSource(_ source: WindowPlacementDecisionSource?) -> WindowPlacementDecision {
        var copy = self
        copy.source = source?.rawValue
        return copy
    }
}

package struct WindowRegistrationSnapshot: Sendable {
    package var rect: Rect?
    package var placementDecision: WindowPlacementDecision

    package init(
        rect: Rect?,
        placementDecision: WindowPlacementDecision,
    ) {
        self.rect = rect
        self.placementDecision = placementDecision
    }
}
