@testable import FrameEngine
@testable import FrameMacOS
import AppKit
import FrameTestSupport
import XCTest

final class WindowClassifierTest: XCTestCase {
    func testStandardDocumentWindowWithChromeIsTiling() {
        let decision = WindowClassifier.classify(makeFacts())

        assertEquals(decision.placementKind, .tiling)
        assertEquals(decision.reason, "standard_window_like_subrole")
    }

    func testOfficeButtonlessTransientWindowIsExcluded() {
        let decision = WindowClassifier.classify(
            makeFacts(
                knownBundleId: .powerPoint,
                subrole: "AXUnknown",
                title: "",
                hasCloseButton: false,
                hasMinimizeButton: false,
                hasZoomButton: false,
                hasFullscreenButton: false,
                isCloseButtonEnabled: nil,
                isMinimizeButtonEnabled: nil,
                isZoomButtonEnabled: nil,
                isFullscreenButtonEnabled: nil,
            )
        )

        assertEquals(decision.placementKind, .excluded)
        assertEquals(decision.reason, "office_buttonless_popup")
    }

    func testOfficeMainDocumentWindowWithChromeIsTiling() {
        let decision = WindowClassifier.classify(
            makeFacts(
                knownBundleId: .powerPoint,
                matchesMainWindow: true,
                hasFullscreenButton: true,
                isFullscreenButtonEnabled: true,
            )
        )

        assertEquals(decision.placementKind, .tiling)
        assertEquals(decision.reason, "standard_window_like_subrole")
    }

    func testWindowWithoutFullscreenButtonCanStillBeStandardChrome() {
        let decision = WindowClassifier.classify(
            makeFacts(
                knownBundleId: .chrome,
                hasFullscreenButton: false,
                isFullscreenButtonEnabled: nil,
            )
        )

        assertEquals(decision.placementKind, .tiling)
        assertEquals(decision.reason, "standard_window_like_subrole")
    }

    func testFirefoxDisabledMinimizeWindowIsExcluded() {
        let decision = WindowClassifier.classify(
            makeFacts(
                knownBundleId: .mozillaFirefox,
                isMinimizeButtonEnabled: false,
            )
        )

        assertEquals(decision.placementKind, .excluded)
        assertEquals(decision.reason, "firefox_disabled_minimize_dialog")
    }

    func testGhosttyQuickTerminalIsExcluded() {
        let decision = WindowClassifier.classify(
            makeFacts(
                knownBundleId: .ghostty,
                identifier: "com.mitchellh.ghostty.quickTerminal",
            )
        )

        assertEquals(decision.placementKind, .excluded)
        assertEquals(decision.reason, "ghostty_quick_terminal")
    }

    func testUnknownWindowShapeFallsBackDeterministically() {
        let decision = WindowClassifier.classify(
            makeFacts(
                subrole: "AXUnknown",
                hasCloseButton: true,
                hasMinimizeButton: false,
                hasZoomButton: false,
                hasFullscreenButton: true,
            )
        )

        assertEquals(decision.placementKind, .excluded)
        assertEquals(decision.reason, "unsupported_subrole_popup")
    }

    func testResolvePlacementDecisionUsesFocusedWindowLookupWhenCacheMisses() {
        let popupWindowId: UInt32 = 38625
        let mainWindowId: UInt32 = 38612
        let popupWindow = makeSyntheticWindow(
            windowId: popupWindowId,
            title: "",
            subrole: "AXUnknown",
            isFocused: true,
            isMain: false,
            hasCloseButton: false,
            hasMinimizeButton: false,
            hasZoomButton: false,
            hasFullscreenButton: false,
        )
        let mainWindow = makeSyntheticWindow(
            windowId: mainWindowId,
            title: "Deck",
            subrole: kAXStandardWindowSubrole,
        )
        let axApp: [String: Json] = [
            "AXFocusedWindow": .dict(popupWindow),
            "AXMainWindow": .dict(mainWindow),
        ]

        let decision = WindowPlacementDecisionResolver.resolve(
            windowId: popupWindowId,
            cachedWindow: nil,
            axApp: axApp,
            appId: KnownBundleId.powerPoint.rawValue,
            knownBundleId: .powerPoint,
            activationPolicy: .regular,
            windowLevel: .normalWindow,
        )

        assertEquals(decision.placementKind, .excluded)
        assertEquals(decision.reason, "office_buttonless_popup")
        assertEquals(decision.source, WindowPlacementDecisionSource.focusedWindowLookup.rawValue)
        assertEquals(decision.debugInfo?.windowId, popupWindowId)
    }

    func testResolveRegistrationSnapshotUsesFocusedWindowLookupWhenCacheMisses() {
        let popupWindowId: UInt32 = 38625
        let popupWindow = makeSyntheticWindow(
            windowId: popupWindowId,
            title: "",
            subrole: "AXUnknown",
            isFocused: true,
            isMain: false,
            hasCloseButton: false,
            hasMinimizeButton: false,
            hasZoomButton: false,
            hasFullscreenButton: false,
        )
        let axApp: [String: Json] = [
            "AXFocusedWindow": .dict(popupWindow),
        ]

        let snapshot = WindowPlacementDecisionResolver.resolveRegistrationSnapshot(
            windowId: popupWindowId,
            cachedWindow: nil,
            axApp: axApp,
            appId: KnownBundleId.powerPoint.rawValue,
            knownBundleId: .powerPoint,
            activationPolicy: .regular,
            windowLevel: .normalWindow,
        )

        assertEquals(snapshot?.placementDecision.placementKind, .excluded)
        assertEquals(snapshot?.placementDecision.reason, "office_buttonless_popup")
        assertEquals(snapshot?.placementDecision.source, WindowPlacementDecisionSource.focusedWindowLookup.rawValue)
    }

    func testResolvePlacementDecisionUsesWindowsListLookupWhenCacheMisses() {
        let popupWindowId: UInt32 = 38629
        let popupWindow = makeSyntheticWindow(
            windowId: popupWindowId,
            title: "",
            subrole: "AXUnknown",
            isFocused: false,
            isMain: false,
            hasCloseButton: false,
            hasMinimizeButton: false,
            hasZoomButton: false,
            hasFullscreenButton: false,
        )
        let axApp: [String: Json] = [
            "AXFocusedWindow": .dict(makeSyntheticWindow(windowId: 38612, title: "Deck", subrole: kAXStandardWindowSubrole)),
            "AXWindows": .array([.dict(popupWindow)]),
        ]

        let decision = WindowPlacementDecisionResolver.resolve(
            windowId: popupWindowId,
            cachedWindow: nil,
            axApp: axApp,
            appId: KnownBundleId.powerPoint.rawValue,
            knownBundleId: .powerPoint,
            activationPolicy: .regular,
            windowLevel: .normalWindow,
        )

        assertEquals(decision.placementKind, .excluded)
        assertEquals(decision.reason, "office_buttonless_popup")
        assertEquals(decision.source, WindowPlacementDecisionSource.windowsListLookup.rawValue)
    }

    func testResolveRegistrationSnapshotUsesWindowsListLookupWhenCacheMisses() {
        let popupWindowId: UInt32 = 38629
        let popupWindow = makeSyntheticWindow(
            windowId: popupWindowId,
            title: "",
            subrole: "AXUnknown",
            isFocused: false,
            isMain: false,
            hasCloseButton: false,
            hasMinimizeButton: false,
            hasZoomButton: false,
            hasFullscreenButton: false,
        )
        let axApp: [String: Json] = [
            "AXFocusedWindow": .dict(makeSyntheticWindow(windowId: 38612, title: "Deck", subrole: kAXStandardWindowSubrole)),
            "AXWindows": .array([.dict(popupWindow)]),
        ]

        let snapshot = WindowPlacementDecisionResolver.resolveRegistrationSnapshot(
            windowId: popupWindowId,
            cachedWindow: nil,
            axApp: axApp,
            appId: KnownBundleId.powerPoint.rawValue,
            knownBundleId: .powerPoint,
            activationPolicy: .regular,
            windowLevel: .normalWindow,
        )

        assertEquals(snapshot?.placementDecision.placementKind, .excluded)
        assertEquals(snapshot?.placementDecision.reason, "office_buttonless_popup")
        assertEquals(snapshot?.placementDecision.source, WindowPlacementDecisionSource.windowsListLookup.rawValue)
    }

    func testResolvePlacementDecisionReturnsExplicitFallbackWhenWindowDisappeared() {
        let decision = WindowPlacementDecisionResolver.resolve(
            windowId: 999,
            cachedWindow: nil,
            axApp: ["AXWindows": .array([])],
            appId: KnownBundleId.powerPoint.rawValue,
            knownBundleId: .powerPoint,
            activationPolicy: .regular,
            windowLevel: .normalWindow,
        )

        assertEquals(decision.placementKind, .excluded)
        assertEquals(decision.reason, WindowPlacementDecisionSource.disappearedBeforeClassification.rawValue)
        assertEquals(decision.source, WindowPlacementDecisionSource.disappearedBeforeClassification.rawValue)
        assertEquals(decision.debugInfo, nil)
    }

    func testResolveRegistrationSnapshotReturnsNilWhenWindowDisappeared() {
        let snapshot = WindowPlacementDecisionResolver.resolveRegistrationSnapshot(
            windowId: 999,
            cachedWindow: nil,
            axApp: ["AXWindows": .array([])],
            appId: KnownBundleId.powerPoint.rawValue,
            knownBundleId: .powerPoint,
            activationPolicy: .regular,
            windowLevel: .normalWindow,
        )

        XCTAssertNil(snapshot)
    }

    private func makeFacts(
        knownBundleId: KnownBundleId? = nil,
        subrole: String? = kAXStandardWindowSubrole,
        title: String? = "Window",
        identifier: String? = nil,
        matchesMainWindow: Bool = false,
        matchesFocusedWindow: Bool = false,
        hasCloseButton: Bool = true,
        hasMinimizeButton: Bool = true,
        hasZoomButton: Bool = true,
        hasFullscreenButton: Bool = true,
        isCloseButtonEnabled: Bool? = true,
        isMinimizeButtonEnabled: Bool? = true,
        isZoomButtonEnabled: Bool? = true,
        isFullscreenButtonEnabled: Bool? = true,
    ) -> WindowFacts {
        WindowFacts(
            appId: knownBundleId?.rawValue,
            knownBundleId: knownBundleId,
            windowId: 1,
            title: title,
            role: kAXWindowRole,
            subrole: subrole,
            identifier: identifier,
            isFocused: false,
            isMain: false,
            isModal: false,
            isMinimized: false,
            isFullscreen: false,
            matchesMainWindow: matchesMainWindow,
            matchesFocusedWindow: matchesFocusedWindow,
            windowLevel: .normalWindow,
            activationPolicy: .regular,
            hasCloseButton: hasCloseButton,
            hasMinimizeButton: hasMinimizeButton,
            hasZoomButton: hasZoomButton,
            hasFullscreenButton: hasFullscreenButton,
            isCloseButtonEnabled: isCloseButtonEnabled,
            isMinimizeButtonEnabled: isMinimizeButtonEnabled,
            isZoomButtonEnabled: isZoomButtonEnabled,
            isFullscreenButtonEnabled: isFullscreenButtonEnabled,
        )
    }

    private func makeSyntheticWindow(
        windowId: UInt32,
        title: String,
        subrole: String,
        isFocused: Bool = false,
        isMain: Bool = false,
        hasCloseButton: Bool = true,
        hasMinimizeButton: Bool = true,
        hasZoomButton: Bool = true,
        hasFullscreenButton: Bool = true,
    ) -> [String: Json] {
        [
            "Aero.axWindowId": .uint32(windowId),
            "AXTitle": .string(title),
            "AXRole": .string(kAXWindowRole),
            "AXSubrole": .string(subrole),
            "AXFocused": .bool(isFocused),
            "AXMain": .bool(isMain),
            "AXCloseButton": hasCloseButton ? .dict(["Aero.axWindowId": .uint32(windowId), "AXEnabled": .bool(true)]) : .null,
            "AXMinimizeButton": hasMinimizeButton ? .dict(["Aero.axWindowId": .uint32(windowId), "AXEnabled": .bool(true)]) : .null,
            "AXZoomButton": hasZoomButton ? .dict(["Aero.axWindowId": .uint32(windowId), "AXEnabled": .bool(true)]) : .null,
            "AXFullScreenButton": hasFullscreenButton ? .dict(["Aero.axWindowId": .uint32(windowId), "AXEnabled": .bool(true)]) : .null,
        ]
    }
}
