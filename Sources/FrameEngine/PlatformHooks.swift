import Common
import Foundation

package typealias PlatformAppWindowMapping = [(any WindowPlatformApp, [UInt32])]

/// Engine-facing platform operations. FrameEngine consumes this surface from AppSession,
/// while FrameMacOS installs the concrete macOS implementation during runtime startup.
@MainActor
package struct PlatformServices {
    package var mainMonitor: @MainActor @Sendable () -> any Monitor
    package var monitors: @MainActor @Sendable () -> [any Monitor]
    package var nativeFocusedWindow: @MainActor @Sendable () async throws -> Window?
    package var frontmostAppBundleId: @MainActor @Sendable () -> String?
    package var refreshPlatformApps: @MainActor @Sendable (_ frontmostAppBundleId: String?) async throws -> PlatformAppWindowMapping
    package var syncUiState: @MainActor @Sendable (_ session: AppSession) -> Void
    package var mouseLocation: @MainActor @Sendable () -> CGPoint
    package var followFocusedMonitorWithMouse: @MainActor @Sendable (_ target: CGPoint) -> Void
    package var nativeFocusWindow: @MainActor @Sendable (_ app: any WindowPlatformApp, _ windowId: UInt32) -> Void

    package init(
        mainMonitor: @escaping @MainActor @Sendable () -> any Monitor = { defaultTestMonitor },
        monitors: @escaping @MainActor @Sendable () -> [any Monitor] = { [defaultTestMonitor] },
        nativeFocusedWindow: @escaping @MainActor @Sendable () async throws -> Window? = { nil },
        frontmostAppBundleId: @escaping @MainActor @Sendable () -> String? = { nil },
        refreshPlatformApps: @escaping @MainActor @Sendable (_ frontmostAppBundleId: String?) async throws -> PlatformAppWindowMapping = { _ in [] },
        syncUiState: @escaping @MainActor @Sendable (_ session: AppSession) -> Void = { _ in },
        mouseLocation: @escaping @MainActor @Sendable () -> CGPoint = { .zero },
        followFocusedMonitorWithMouse: @escaping @MainActor @Sendable (_ target: CGPoint) -> Void = { _ in },
        nativeFocusWindow: @escaping @MainActor @Sendable (_ app: any WindowPlatformApp, _ windowId: UInt32) -> Void = { _, _ in }
    ) {
        self.mainMonitor = mainMonitor
        self.monitors = monitors
        self.nativeFocusedWindow = nativeFocusedWindow
        self.frontmostAppBundleId = frontmostAppBundleId
        self.refreshPlatformApps = refreshPlatformApps
        self.syncUiState = syncUiState
        self.mouseLocation = mouseLocation
        self.followFocusedMonitorWithMouse = followFocusedMonitorWithMouse
        self.nativeFocusWindow = nativeFocusWindow
    }
}

@TaskLocal package var _isStartup: Bool? = false
package var isStartup: Bool { _isStartup ?? dieT("isStartup is not initialized") }
