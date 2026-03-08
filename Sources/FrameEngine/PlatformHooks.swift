import AppKit
import Common

package typealias PlatformAppWindowMapping = [(any WindowPlatformApp, [UInt32])]

/// Engine-facing platform operations. FrameEngine consumes this surface from AppSession,
/// while FrameMacOS installs the concrete macOS implementation during runtime startup.
@MainActor
package struct PlatformServices {
    package var nativeFocusedWindow: @MainActor @Sendable () async throws -> Window?
    package var frontmostAppBundleId: @MainActor @Sendable () -> String?
    package var refreshPlatformApps: @MainActor @Sendable (_ frontmostAppBundleId: String?) async throws -> PlatformAppWindowMapping
    package var syncUiState: @MainActor @Sendable (_ session: AppSession) -> Void
    package var mouseLocation: @MainActor @Sendable () -> CGPoint

    package init(
        nativeFocusedWindow: @escaping @MainActor @Sendable () async throws -> Window? = { nil },
        frontmostAppBundleId: @escaping @MainActor @Sendable () -> String? = { nil },
        refreshPlatformApps: @escaping @MainActor @Sendable (_ frontmostAppBundleId: String?) async throws -> PlatformAppWindowMapping = { _ in [] },
        syncUiState: @escaping @MainActor @Sendable (_ session: AppSession) -> Void = { _ in },
        mouseLocation: @escaping @MainActor @Sendable () -> CGPoint = {
            let mainMonitorHeight: CGFloat = mainMonitor.height
            let location = NSEvent.mouseLocation
            return location.copy(\.y, mainMonitorHeight - location.y)
        }
    ) {
        self.nativeFocusedWindow = nativeFocusedWindow
        self.frontmostAppBundleId = frontmostAppBundleId
        self.refreshPlatformApps = refreshPlatformApps
        self.syncUiState = syncUiState
        self.mouseLocation = mouseLocation
    }
}

@TaskLocal package var _isStartup: Bool? = false
package var isStartup: Bool { _isStartup ?? dieT("isStartup is not initialized") }
