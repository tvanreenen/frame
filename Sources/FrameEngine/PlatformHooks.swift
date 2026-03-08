import AppKit
import Common

package typealias PlatformAppWindowMapping = [(any WindowPlatformApp, [UInt32])]

@TaskLocal package var _isStartup: Bool? = false
package var isStartup: Bool { _isStartup ?? dieT("isStartup is not initialized") }

@MainActor package var currentlyManipulatedWithMouseWindowId: UInt32? = nil

package var mouseLocation: CGPoint {
    let mainMonitorHeight: CGFloat = mainMonitor.height
    let location = NSEvent.mouseLocation
    return location.copy(\.y, mainMonitorHeight - location.y)
}

@MainActor package var nativeFocusedWindowProvider: @MainActor @Sendable () async throws -> Window? = { nil }
@MainActor package var refreshPlatformAppsProvider: @MainActor @Sendable (_ frontmostAppBundleId: String?) async throws -> PlatformAppWindowMapping = { _ in [] }
@MainActor package var uiStateSyncHook: @MainActor @Sendable (_ session: AppSession) -> Void = { _ in }
