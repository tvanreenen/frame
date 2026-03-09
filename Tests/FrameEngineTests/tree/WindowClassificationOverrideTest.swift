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

    func testLegacyFloatingCase_nomachinePopupCanBeOverriddenToDialog() async throws {
        let app = ClassificationTestApp(
            pid: 101,
            rawAppBundleId: "com.nomachine.nxdock",
            name: "NoMachine",
            placementKind: .popup,
            windowTitle: "",
        )
        let withoutOverride = try await Window.resolvePlacementKind(windowId: 1, app: app)
        assertEquals(withoutOverride, .popup)

        let parsed = parseConfig(
            """
            [[window-classification-override]]
                if.app-id = 'com.nomachine.nxdock'
                kind = 'dialog'
            """,
        )
        assertEquals(parsed.errors, [])
        runtimeContext.config.windowClassificationOverrides = parsed.config.windowClassificationOverrides

        let withOverride = try await Window.resolvePlacementKind(windowId: 1, app: app)
        assertEquals(withOverride, .floating)
    }

    func testLegacyFloatingCase_cleanshotPopupCanBeOverriddenByAppNameRegex() async throws {
        let app = ClassificationTestApp(
            pid: 102,
            rawAppBundleId: "pl.maketheweb.cleanshotx",
            name: "CleanShot X",
            placementKind: .popup,
            windowTitle: "",
        )
        let withoutOverride = try await Window.resolvePlacementKind(windowId: 1, app: app)
        assertEquals(withoutOverride, .popup)

        let parsed = parseConfig(
            """
            [[window-classification-override]]
                if.app-name-regex-substring = 'cleanshot'
                kind = 'dialog'
            """,
        )
        assertEquals(parsed.errors, [])
        runtimeContext.config.windowClassificationOverrides = parsed.config.windowClassificationOverrides

        let withOverride = try await Window.resolvePlacementKind(windowId: 1, app: app)
        assertEquals(withOverride, .floating)
    }
}

private final class ClassificationTestApp: WindowPlatformApp {
    let pid: Int32
    let rawAppBundleId: String?
    let name: String?
    let execPath: String? = nil
    let bundlePath: String? = nil
    let isHidden: Bool = false

    private let placementKind: WindowPlacementKind
    private let windowTitle: String?

    init(pid: Int32, rawAppBundleId: String?, name: String?, placementKind: WindowPlacementKind, windowTitle: String?) {
        self.pid = pid
        self.rawAppBundleId = rawAppBundleId
        self.name = name
        self.placementKind = placementKind
        self.windowTitle = windowTitle
    }

    @MainActor func getFocusedWindow() async throws -> Window? { nil }
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
    func getWindowPlacementKind(windowId: UInt32) async throws -> WindowPlacementKind {
        placementKind
    }
}
