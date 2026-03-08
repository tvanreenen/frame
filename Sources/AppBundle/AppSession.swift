import AppKit
import Common
import Foundation

struct AppSessionCallbackContext: @unchecked Sendable {
    let rawValue: UnsafeMutableRawPointer
}

@MainActor
final class AppSession {
    var config: Config
    var configUrl: URL
    var windowsById: [UInt32: Window]
    var appsByPid: [pid_t: MacApp]
    var appsWipByPid: [pid_t: AwaitableOneTimeBroadcastLatch]
    var appFocusJob: RunLoopJob?
    var closedWindowsCache: FrozenWorld

    var activeRefreshTask: Task<(), any Error>? = nil

    var focusState: FrozenFocus? = nil
    var lastKnownFocus: FrozenFocus? = nil
    var prevFocusedWorkspaceName: String? = nil
    var prevFocusedWorkspaceDate: Date = .distantPast
    var focusCallbacksRecursionGuard = false

    var workspaceNameToWorkspace: [String: Workspace] = [:]
    var screenPointToPrevVisibleWorkspace: [CGPoint: String] = [:]
    var screenPointToVisibleWorkspace: [CGPoint: Workspace] = [:]
    var visibleWorkspaceToScreenPoint: [Workspace: CGPoint] = [:]

    init(config: Config, configUrl: URL) {
        self.config = config
        self.configUrl = configUrl
        windowsById = [:]
        appsByPid = [:]
        appsWipByPid = [:]
        appFocusJob = nil
        closedWindowsCache = FrozenWorld(workspaces: [], monitors: [], windowIds: [])
    }

    func initializedFocus() -> FrozenFocus {
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

    func initializedLastKnownFocus() -> FrozenFocus {
        if let existing = lastKnownFocus {
            return existing
        }
        let focus = initializedFocus()
        lastKnownFocus = focus
        return focus
    }

    func runAsCurrentSession<T>(_ body: () async throws -> T) async throws -> T {
        let previousSession = currentSession
        currentSession = self
        defer { currentSession = previousSession }
        return try await body()
    }

    nonisolated var callbackContext: AppSessionCallbackContext {
        .init(rawValue: Unmanaged.passUnretained(self).toOpaque())
    }

    nonisolated static func fromCallbackContext(_ data: UnsafeMutableRawPointer?) -> AppSession? {
        data.map { Unmanaged<AppSession>.fromOpaque($0).takeUnretainedValue() }
    }

    nonisolated static func fromCallbackContext(_ data: AppSessionCallbackContext?) -> AppSession? {
        fromCallbackContext(data?.rawValue)
    }
}
