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
            heuristicType: .popup,
            windowTitle: "",
        )
        let withoutOverride = try await Window.resolveWindowType(windowId: 1, app: app, windowLevel: nil)
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

        let withOverride = try await Window.resolveWindowType(windowId: 1, app: app, windowLevel: nil)
        assertEquals(withOverride, .dialog)
    }

    func testLegacyFloatingCase_cleanshotPopupCanBeOverriddenByAppNameRegex() async throws {
        let app = ClassificationTestApp(
            pid: 102,
            rawAppBundleId: "pl.maketheweb.cleanshotx",
            name: "CleanShot X",
            heuristicType: .popup,
            windowTitle: "",
        )
        let withoutOverride = try await Window.resolveWindowType(windowId: 1, app: app, windowLevel: nil)
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

        let withOverride = try await Window.resolveWindowType(windowId: 1, app: app, windowLevel: nil)
        assertEquals(withOverride, .dialog)
    }
}

private final class ClassificationTestApp: WindowPlatformApp {
    let pid: Int32
    let rawAppBundleId: String?
    let name: String?
    let execPath: String? = nil
    let bundlePath: String? = nil
    let isHidden: Bool = false

    private let heuristicType: AxUiElementWindowType
    private let windowTitle: String?

    init(pid: Int32, rawAppBundleId: String?, name: String?, heuristicType: AxUiElementWindowType, windowTitle: String?) {
        self.pid = pid
        self.rawAppBundleId = rawAppBundleId
        self.name = name
        self.heuristicType = heuristicType
        self.windowTitle = windowTitle
    }

    @MainActor func getFocusedWindow() async throws -> Window? { nil }
    @MainActor func setLastNativeFocusedWindowId(_ windowId: UInt32?) {}
    @MainActor func nativeFocus(windowId: UInt32) {}
    @MainActor func closeAndUnregisterAxWindow(windowId: UInt32) {}

    func getAxRect(windowId: UInt32) async throws -> Rect? { nil }
    func getAxTopLeftCorner(windowId: UInt32) async throws -> CGPoint? { nil }
    func getAxSize(windowId: UInt32) async throws -> CGSize? { nil }
    func setAxFrame(windowId: UInt32, topLeft: CGPoint?, size: CGSize?) {}
    func setAxFrameBlocking(windowId: UInt32, topLeft: CGPoint?, size: CGSize?) async throws {}
    func isMacosNativeFullscreen(windowId: UInt32) async throws -> Bool? { false }
    func isMacosNativeMinimized(windowId: UInt32) async throws -> Bool? { false }
    func getAxTitle(windowId: UInt32) async throws -> String? { windowTitle }
    func dumpWindowAxInfo(windowId: UInt32) async throws -> [String: Json] { [:] }
    func getAxUiElementWindowType(windowId: UInt32, windowLevel: MacOsWindowLevel?) async throws -> AxUiElementWindowType {
        heuristicType
    }
}
