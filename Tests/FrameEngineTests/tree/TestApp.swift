@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import AppKit
import Common

final class TestApp: WindowPlatformApp {
    let pid: Int32
    let rawAppBundleId: String?
    let name: String?
    let execPath: String? = nil
    let bundlePath: String? = nil
    var isHidden: Bool = false

    @MainActor
    static let shared = TestApp()

    private init() {
        self.pid = 0
        self.rawAppBundleId = "com.frame.test-app"
        self.name = rawAppBundleId
    }

    private var _windows: [Window] = []
    var windows: [Window] {
        get { _windows }
        set {
            if let focusedWindow {
                check(newValue.contains(focusedWindow))
            }
            _windows = newValue
        }
    }

    private var _focusedWindow: Window? = nil
    var focusedWindow: Window? {
        get { _focusedWindow }
        set {
            if let window = newValue {
                check(windows.contains(window))
            }
            _focusedWindow = newValue
        }
    }

    private var windowRects: [UInt32: Rect] = [:]
    private var windowTitles: [UInt32: String] = [:]
    private var windowTypes: [UInt32: AxUiElementWindowType] = [:]
    private var macosFullscreen: [UInt32: Bool] = [:]
    private var macosMinimized: [UInt32: Bool] = [:]

    @MainActor
    @discardableResult
    func registerWindow(id: UInt32, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat = 1, rect: Rect? = nil, title: String? = nil) -> Window {
        let window = Window(id: id, self, lastFloatingSize: nil, parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
        Window.registerForTests(window)
        windows.append(window)
        if let rect {
            windowRects[id] = rect
        }
        windowTitles[id] = title ?? "TestWindow(\(id))"
        return window
    }

    @MainActor
    func resetState() {
        focusedWindow = nil
        windows = []
        windowRects = [:]
        windowTitles = [:]
        windowTypes = [:]
        macosFullscreen = [:]
        macosMinimized = [:]
        isHidden = false
    }

    @MainActor
    func setWindowType(windowId: UInt32, _ type: AxUiElementWindowType) {
        windowTypes[windowId] = type
    }

    @MainActor
    func setMacosFullscreen(windowId: UInt32, _ isFullscreen: Bool) {
        macosFullscreen[windowId] = isFullscreen
    }

    @MainActor
    func setMacosMinimized(windowId: UInt32, _ isMinimized: Bool) {
        macosMinimized[windowId] = isMinimized
    }

    @MainActor func getFocusedWindow() async throws -> Window? { focusedWindow }
    @MainActor func setLastNativeFocusedWindowId(_ windowId: UInt32?) {}

    func getAxRect(windowId: UInt32) async throws -> Rect? {
        windowRects[windowId]
    }

    func getAxTopLeftCorner(windowId: UInt32) async throws -> CGPoint? {
        windowRects[windowId]?.topLeftCorner
    }

    func getAxSize(windowId: UInt32) async throws -> CGSize? {
        windowRects[windowId]?.size
    }

    func setAxFrame(windowId: UInt32, topLeft: CGPoint?, size: CGSize?) {
        let existing = windowRects[windowId]
        let resolvedTopLeft = topLeft ?? existing?.topLeftCorner
        let resolvedSize = size ?? existing?.size
        guard let resolvedTopLeft, let resolvedSize else { return }
        windowRects[windowId] = Rect(
            topLeftX: resolvedTopLeft.x,
            topLeftY: resolvedTopLeft.y,
            width: resolvedSize.width,
            height: resolvedSize.height,
        )
    }

    func setAxFrameBlocking(windowId: UInt32, topLeft: CGPoint?, size: CGSize?) async throws {
        setAxFrame(windowId: windowId, topLeft: topLeft, size: size)
    }

    @MainActor
    func nativeFocus(windowId: UInt32) {
        appForTests = self
        focusedWindow = Window.get(byId: windowId)
    }

    @MainActor
    func closeAndUnregisterAxWindow(windowId: UInt32) {
        Window.allWindowsMap[windowId]?.unbindFromParent()
        Window.allWindowsMap.removeValue(forKey: windowId)
        windows.removeAll { $0.windowId == windowId }
        if focusedWindow?.windowId == windowId {
            focusedWindow = nil
        }
        windowRects.removeValue(forKey: windowId)
        windowTitles.removeValue(forKey: windowId)
        windowTypes.removeValue(forKey: windowId)
        macosFullscreen.removeValue(forKey: windowId)
        macosMinimized.removeValue(forKey: windowId)
    }

    func isMacosNativeFullscreen(windowId: UInt32) async throws -> Bool? {
        macosFullscreen[windowId] ?? false
    }

    func isMacosNativeMinimized(windowId: UInt32) async throws -> Bool? {
        macosMinimized[windowId] ?? false
    }

    func getAxTitle(windowId: UInt32) async throws -> String? {
        windowTitles[windowId] ?? ""
    }

    func dumpWindowAxInfo(windowId: UInt32) async throws -> [String: Json] {
        [:]
    }

    func getAxUiElementWindowType(windowId: UInt32, windowLevel: MacOsWindowLevel?) async throws -> AxUiElementWindowType {
        windowTypes[windowId] ?? .window
    }
}
