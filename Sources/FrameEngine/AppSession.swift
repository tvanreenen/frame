import Common
import Foundation

package struct AppSessionCallbackContext: @unchecked Sendable {
    package let rawValue: UnsafeMutableRawPointer
}

@MainActor
package final class AppSession {
    package var config: Config
    package var configUrl: URL
    package var windowsById: [UInt32: Window]
    package var appsByPid: [pid_t: any WindowPlatformApp]
    package var appsWipByPid: [pid_t: AwaitableOneTimeBroadcastLatch]
    package var appFocusJob: RunLoopJob?
    package var closedWindowsCache: FrozenWorld

    package var activeRefreshTask: Task<(), any Error>? = nil

    package var focusState: FrozenFocus? = nil
    package var lastKnownFocus: FrozenFocus? = nil
    package var prevFocusedWorkspaceName: String? = nil
    package var prevFocusedWorkspaceDate: Date = .distantPast
    package var focusCallbacksRecursionGuard = false

    package var workspaceNameToWorkspace: [String: Workspace] = [:]
    package var screenPointToPrevVisibleWorkspace: [CGPoint: String] = [:]
    package var screenPointToVisibleWorkspace: [CGPoint: Workspace] = [:]
    package var visibleWorkspaceToScreenPoint: [Workspace: CGPoint] = [:]

    // Session-owned seam for platform lookups, refresh, UI sync, and mouse state.
    package var platformServices: PlatformServices
    package var currentlyManipulatedWithMouseWindowId: UInt32? = nil
    nonisolated package let windowEventsDiagnosticsLogger: WindowEventsDiagnosticsLogger

    package init(config: Config, configUrl: URL) {
        self.config = config
        self.configUrl = configUrl
        windowsById = [:]
        appsByPid = [:]
        appsWipByPid = [:]
        appFocusJob = nil
        closedWindowsCache = FrozenWorld(workspaces: [], monitors: [], windowIds: [])
        platformServices = PlatformServices()
        windowEventsDiagnosticsLogger = WindowEventsDiagnosticsLogger()
    }

    package func initializedFocus() -> FrozenFocus {
        if let existing = focusState {
            return existing
        }
        let monitor = mainMonitor
        let focus = FrozenFocus(
            windowId: nil,
            workspaceName: monitor.activeWorkspace.name,
            monitorId: monitor.monitorId ?? 0,
        )
        focusState = focus
        lastKnownFocus = focus
        return focus
    }

    package func initializedLastKnownFocus() -> FrozenFocus {
        if let existing = lastKnownFocus {
            return existing
        }
        let focus = initializedFocus()
        lastKnownFocus = focus
        return focus
    }

    package func runAsCurrentSession<T>(_ body: () async throws -> T) async throws -> T {
        let previousSession = currentSession
        currentSession = self
        defer { currentSession = previousSession }
        return try await body()
    }

    nonisolated package var callbackContext: AppSessionCallbackContext {
        .init(rawValue: Unmanaged.passUnretained(self).toOpaque())
    }

    nonisolated package static func fromCallbackContext(_ data: UnsafeMutableRawPointer?) -> AppSession? {
        data.map { Unmanaged<AppSession>.fromOpaque($0).takeUnretainedValue() }
    }

    nonisolated package static func fromCallbackContext(_ data: AppSessionCallbackContext?) -> AppSession? {
        fromCallbackContext(data?.rawValue)
    }
}
