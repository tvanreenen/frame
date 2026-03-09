import FrameEngine
import FrameMacOS
import FrameUI
import AppKit
import Common

package final class TestApp: WindowPlatformApp {
    package let pid: Int32
    package let rawAppBundleId: String?
    package let name: String?
    package let execPath: String? = nil
    package let bundlePath: String? = nil
    package var isHidden: Bool = false

    @MainActor
    package static let shared = TestApp()

    private init() {
        self.pid = 0
        self.rawAppBundleId = "com.frame.test-app"
        self.name = rawAppBundleId
    }

    private var _windows: [Window] = []
    package var windows: [Window] {
        get { _windows }
        set {
            if let focusedWindow {
                check(newValue.contains(focusedWindow))
            }
            _windows = newValue
        }
    }

    private var _focusedWindow: Window? = nil
    package var focusedWindow: Window? {
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
    private var windowPlacementKinds: [UInt32: WindowPlacementKind] = [:]
    private var macosFullscreen: [UInt32: Bool] = [:]
    private var macosMinimized: [UInt32: Bool] = [:]

    @MainActor
    @discardableResult
    package func registerWindow(id: UInt32, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat = 1, rect: Rect? = nil, title: String? = nil) -> Window {
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
    package func resetState() {
        focusedWindow = nil
        windows = []
        windowRects = [:]
        windowTitles = [:]
        windowPlacementKinds = [:]
        macosFullscreen = [:]
        macosMinimized = [:]
        isHidden = false
    }

    @MainActor
    package func setWindowPlacementKind(windowId: UInt32, _ kind: WindowPlacementKind) {
        windowPlacementKinds[windowId] = kind
    }

    @MainActor
    package func setNativeFullscreen(windowId: UInt32, _ isFullscreen: Bool) {
        macosFullscreen[windowId] = isFullscreen
    }

    @MainActor
    package func setNativeMinimized(windowId: UInt32, _ isMinimized: Bool) {
        macosMinimized[windowId] = isMinimized
    }

    @MainActor package func getFocusedWindow() async throws -> Window? { focusedWindow }
    @MainActor package func setLastNativeFocusedWindowId(_ windowId: UInt32?) {}

    package func getWindowRect(windowId: UInt32) async throws -> Rect? {
        windowRects[windowId]
    }

    package func getWindowTopLeftCorner(windowId: UInt32) async throws -> CGPoint? {
        windowRects[windowId]?.topLeftCorner
    }

    package func getWindowSize(windowId: UInt32) async throws -> CGSize? {
        windowRects[windowId]?.size
    }

    package func setWindowFrame(windowId: UInt32, topLeft: CGPoint?, size: CGSize?) {
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

    package func setWindowFrameBlocking(windowId: UInt32, topLeft: CGPoint?, size: CGSize?) async throws {
        setWindowFrame(windowId: windowId, topLeft: topLeft, size: size)
    }

    @MainActor
    package func closeAndUnregisterWindow(windowId: UInt32) {
        Window.allWindowsMap[windowId]?.unbindFromParent()
        Window.allWindowsMap.removeValue(forKey: windowId)
        windows.removeAll { $0.windowId == windowId }
        if focusedWindow?.windowId == windowId {
            focusedWindow = nil
        }
        windowRects.removeValue(forKey: windowId)
        windowTitles.removeValue(forKey: windowId)
        windowPlacementKinds.removeValue(forKey: windowId)
        macosFullscreen.removeValue(forKey: windowId)
        macosMinimized.removeValue(forKey: windowId)
    }

    package func isNativeFullscreen(windowId: UInt32) async throws -> Bool? {
        macosFullscreen[windowId] ?? false
    }

    package func isNativeMinimized(windowId: UInt32) async throws -> Bool? {
        macosMinimized[windowId] ?? false
    }

    package func getWindowTitle(windowId: UInt32) async throws -> String? {
        windowTitles[windowId] ?? ""
    }

    package func dumpWindowInfo(windowId: UInt32) async throws -> [String: Json] {
        [:]
    }

    package func getWindowPlacementKind(windowId: UInt32) async throws -> WindowPlacementKind {
        windowPlacementKinds[windowId] ?? .tiling
    }
}
