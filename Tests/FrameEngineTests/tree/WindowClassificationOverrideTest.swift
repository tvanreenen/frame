@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import AppKit
import Common
import XCTest
import FrameTestSupport

@MainActor
final class WindowClassificationOverrideTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testExcludedCase_nomachinePopupCanBeOverriddenToTiling() async throws {
        let app = ClassificationTestApp(
            pid: 101,
            rawAppBundleId: "com.nomachine.nxdock",
            name: "NoMachine",
            placementKind: .excluded,
            windowTitle: "",
        )
        let withoutOverride = try await Window.resolvePlacementKind(windowId: 1, app: app)
        assertEquals(withoutOverride, .excluded)

        let parsed = parseConfig(
            """
            [[window-classification-override]]
                if.app-id = 'com.nomachine.nxdock'
                kind = 'tiling'
            """,
        )
        assertEquals(parsed.errors, [])
        runtimeContext.config.windowClassificationOverrides = parsed.config.windowClassificationOverrides

        let withOverride = try await Window.resolvePlacementKind(windowId: 1, app: app)
        assertEquals(withOverride, .tiling)
    }

    func testExcludedCase_cleanshotPopupCanBeOverriddenByAppNameRegex() async throws {
        let app = ClassificationTestApp(
            pid: 102,
            rawAppBundleId: "pl.maketheweb.cleanshotx",
            name: "CleanShot X",
            placementKind: .excluded,
            windowTitle: "",
        )
        let withoutOverride = try await Window.resolvePlacementKind(windowId: 1, app: app)
        assertEquals(withoutOverride, .excluded)

        let parsed = parseConfig(
            """
            [[window-classification-override]]
                if.app-name-regex-substring = 'cleanshot'
                kind = 'excluded'
            """,
        )
        assertEquals(parsed.errors, [])
        runtimeContext.config.windowClassificationOverrides = parsed.config.windowClassificationOverrides

        let withOverride = try await Window.resolvePlacementKind(windowId: 1, app: app)
        assertEquals(withOverride, .excluded)
    }

    func testPlacementResolutionDoesNotApplyLegacyOfficeFallbackAfterAppDecision() async throws {
        let app = ClassificationTestApp(
            pid: 103,
            rawAppBundleId: KnownBundleId.powerPoint.rawValue,
            name: "Microsoft PowerPoint",
            placementDecision: WindowPlacementDecision(
                placementKind: .tiling,
                reason: "app_classifier",
            ),
            windowTitle: "",
        )

        let resolved = try await Window.resolvePlacementDecision(windowId: 1, app: app)

        assertEquals(resolved.placementKind, .tiling)
        assertEquals(resolved.reason, "app_classifier")
    }

    func testWindowClassificationOverrideAppliedOnRegistration() async throws {
        var matcher = WindowClassificationOverrideMatcher()
        matcher.appId = TestApp.shared.rawAppBundleId
        var override = WindowClassificationOverride()
        override.matcher = matcher
        override.kind = .tiling
        runtimeContext.config.windowClassificationOverrides = [
            override,
        ]
        TestApp.shared.setWindowPlacementKind(windowId: 781, .excluded)

        let window = try await Window.getOrRegister(windowId: 781, app: TestApp.shared)
        let unwrappedWindow = try XCTUnwrap(window)

        XCTAssertTrue(unwrappedWindow.parent is Column)
    }
}

private final class ClassificationTestApp: WindowPlatformApp {
    let pid: Int32
    let rawAppBundleId: String?
    let name: String?
    let execPath: String? = nil
    let bundlePath: String? = nil
    let isHidden: Bool = false

    private let placementDecision: WindowPlacementDecision
    private let windowTitle: String?

    init(pid: Int32, rawAppBundleId: String?, name: String?, placementKind: WindowPlacementKind, windowTitle: String?) {
        self.pid = pid
        self.rawAppBundleId = rawAppBundleId
        self.name = name
        self.placementDecision = WindowPlacementDecision(placementKind: placementKind, reason: "test_app")
        self.windowTitle = windowTitle
    }

    init(pid: Int32, rawAppBundleId: String?, name: String?, placementDecision: WindowPlacementDecision, windowTitle: String?) {
        self.pid = pid
        self.rawAppBundleId = rawAppBundleId
        self.name = name
        self.placementDecision = placementDecision
        self.windowTitle = windowTitle
    }

    @MainActor func getFocusedPlatformWindowId() async throws -> UInt32? { nil }
    @MainActor func setLastNativeFocusedWindowId(_ windowId: UInt32?) {}
    @MainActor func closeAndUnregisterWindow(windowId: UInt32) {}

    func getWindowRect(windowId: UInt32) async throws -> Rect? { nil }
    func getWindowTopLeftCorner(windowId: UInt32) async throws -> CGPoint? { nil }
    func getWindowSize(windowId: UInt32) async throws -> CGSize? { nil }
    func setWindowFrame(windowId: UInt32, topLeft: CGPoint?, size: CGSize?) {}
    func setWindowFrameBlocking(windowId: UInt32, topLeft: CGPoint?, size: CGSize?) async throws {}
    func isNativeFullscreen(windowId: UInt32) async throws -> Bool? { false }
    func isNativeMinimized(windowId: UInt32) async throws -> Bool? { false }
    func getWindowTitle(windowId: UInt32) async throws -> String? { windowTitle }
    func dumpWindowInfo(windowId: UInt32) async throws -> [String: Json] { [:] }
    func getWindowPlacementDecision(windowId: UInt32) async throws -> WindowPlacementDecision {
        placementDecision
    }
}
