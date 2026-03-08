import AppKit
import Common

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

    func getAxRect(windowId: UInt32) async throws -> Rect?
    func getAxTopLeftCorner(windowId: UInt32) async throws -> CGPoint?
    func getAxSize(windowId: UInt32) async throws -> CGSize?

    func setAxFrame(windowId: UInt32, topLeft: CGPoint?, size: CGSize?)
    func setAxFrameBlocking(windowId: UInt32, topLeft: CGPoint?, size: CGSize?) async throws
    @MainActor func nativeFocus(windowId: UInt32)
    @MainActor func closeAndUnregisterAxWindow(windowId: UInt32)

    func isNativeFullscreen(windowId: UInt32) async throws -> Bool?
    func isNativeMinimized(windowId: UInt32) async throws -> Bool?
    func getAxTitle(windowId: UInt32) async throws -> String?
    func dumpWindowAxInfo(windowId: UInt32) async throws -> [String: Json]

    func getAxUiElementWindowType(windowId: UInt32) async throws -> AxUiElementWindowType
}
