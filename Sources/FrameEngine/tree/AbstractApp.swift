import Common
import Foundation

package protocol AbstractApp: AnyObject, Hashable, AeroAny {
    var pid: Int32 { get }
    var rawAppBundleId: String? { get }

    @MainActor func getFocusedWindow() async throws -> Window?
    var name: String? { get }
    var execPath: String? { get }
    var bundlePath: String? { get }
}

extension AbstractApp {
    package static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.pid == rhs.pid {
            check(lhs === rhs)
            return true
        } else {
            check(lhs !== rhs)
            return false
        }
    }

    package func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }
}

package protocol WindowPlatformApp: AbstractApp {
    var isHidden: Bool { get }
    @MainActor func setLastNativeFocusedWindowId(_ windowId: UInt32?)

    func getWindowRect(windowId: UInt32) async throws -> Rect?
    func getWindowTopLeftCorner(windowId: UInt32) async throws -> CGPoint?
    func getWindowSize(windowId: UInt32) async throws -> CGSize?

    func setWindowFrame(windowId: UInt32, topLeft: CGPoint?, size: CGSize?)
    func setWindowFrameBlocking(windowId: UInt32, topLeft: CGPoint?, size: CGSize?) async throws
    @MainActor func closeAndUnregisterWindow(windowId: UInt32)

    func isNativeFullscreen(windowId: UInt32) async throws -> Bool?
    func isNativeMinimized(windowId: UInt32) async throws -> Bool?
    func getWindowTitle(windowId: UInt32) async throws -> String?
    func dumpWindowInfo(windowId: UInt32) async throws -> [String: Json]

    func getWindowPlacementKind(windowId: UInt32) async throws -> WindowPlacementKind
}
