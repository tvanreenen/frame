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
            focusedPlatformWindowId = newValue?.platformWindowId
            _focusedWindow = newValue
        }
    }
    package var focusedPlatformWindowId: UInt32? = nil

    private var windowRects: [UInt32: Rect] = [:]
    private var windowTitles: [UInt32: String] = [:]
    private var windowPlacementDecisions: [UInt32: WindowPlacementDecision] = [:]
    private var explicitWindowRegistrationSnapshots: [UInt32: WindowRegistrationSnapshot] = [:]
    private var missingRegistrationSnapshotWindowIds: Set<UInt32> = []
    private var macosFullscreen: [UInt32: Bool] = [:]
    private var macosMinimized: [UInt32: Bool] = [:]

    @MainActor
    @discardableResult
    package func registerWindow(id: UInt32, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat = 1, rect: Rect? = nil, title: String? = nil) -> Window {
        let window = Window(
            id: currentSession.makeFrameWindowId(serial: id),
            platformWindowId: id,
            self,
            lastKnownSize: nil,
            parent: parent,
            adaptiveWeight: adaptiveWeight,
            index: INDEX_BIND_LAST,
        )
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
        focusedPlatformWindowId = nil
        windows = []
        windowRects = [:]
        windowTitles = [:]
        windowPlacementDecisions = [:]
        explicitWindowRegistrationSnapshots = [:]
        missingRegistrationSnapshotWindowIds = []
        macosFullscreen = [:]
        macosMinimized = [:]
        isHidden = false
    }

    @MainActor
    package func setWindowPlacementKind(windowId: UInt32, _ kind: WindowPlacementKind) {
        windowPlacementDecisions[windowId] = WindowPlacementDecision(
            placementKind: kind,
            reason: "test_override",
        )
    }

    @MainActor
    package func setWindowPlacementDecision(windowId: UInt32, _ decision: WindowPlacementDecision) {
        windowPlacementDecisions[windowId] = decision
    }

    @MainActor
    package func setWindowRect(windowId: UInt32, _ rect: Rect?) {
        windowRects[windowId] = rect
    }

    @MainActor
    package func setWindowRegistrationSnapshot(windowId: UInt32, _ snapshot: WindowRegistrationSnapshot?) {
        if let snapshot {
            explicitWindowRegistrationSnapshots[windowId] = snapshot
            missingRegistrationSnapshotWindowIds.remove(windowId)
        } else {
            explicitWindowRegistrationSnapshots.removeValue(forKey: windowId)
            missingRegistrationSnapshotWindowIds.insert(windowId)
        }
    }

    @MainActor
    package func setNativeFullscreen(windowId: UInt32, _ isFullscreen: Bool) {
        macosFullscreen[windowId] = isFullscreen
    }

    @MainActor
    package func setNativeMinimized(windowId: UInt32, _ isMinimized: Bool) {
        macosMinimized[windowId] = isMinimized
    }

    @MainActor package func getFocusedPlatformWindowId() async throws -> UInt32? { focusedPlatformWindowId }
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
        Window.get(byPlatformWindowId: windowId)?.unbindFromParent()
        if let logicalWindow = Window.get(byPlatformWindowId: windowId) {
            Window.allWindowsMap.removeValue(forKey: logicalWindow.windowId)
        }
        windows.removeAll { $0.platformWindowId == windowId }
        if focusedWindow?.platformWindowId == windowId {
            focusedWindow = nil
        }
        if focusedPlatformWindowId == windowId {
            focusedPlatformWindowId = nil
        }
        windowRects.removeValue(forKey: windowId)
        windowTitles.removeValue(forKey: windowId)
        windowPlacementDecisions.removeValue(forKey: windowId)
        explicitWindowRegistrationSnapshots.removeValue(forKey: windowId)
        missingRegistrationSnapshotWindowIds.remove(windowId)
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

    package func getWindowRegistrationSnapshot(windowId: UInt32) async throws -> WindowRegistrationSnapshot? {
        if missingRegistrationSnapshotWindowIds.contains(windowId) {
            return nil
        }
        if let snapshot = explicitWindowRegistrationSnapshots[windowId] {
            return snapshot
        }
        return WindowRegistrationSnapshot(
            rect: windowRects[windowId],
            placementDecision: try await getWindowPlacementDecision(windowId: windowId),
        )
    }

    package func getWindowPlacementDecision(windowId: UInt32) async throws -> WindowPlacementDecision {
        windowPlacementDecisions[windowId] ?? WindowPlacementDecision(
            placementKind: .tiling,
            reason: "test_default",
        )
    }
}
