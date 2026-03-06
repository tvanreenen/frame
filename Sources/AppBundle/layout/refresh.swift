import AppKit
import Common

extension AppSession {
    @MainActor
    func scheduleRefreshSession(
        _ event: RefreshSessionEvent,
        optimisticallyPreLayoutWorkspaces: Bool = false,
    ) {
        activeRefreshTask?.cancel()
        activeRefreshTask = Task { @MainActor in
            try checkCancellation()
            try await runRefreshSessionBlocking(event, optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces)
        }
    }

    @MainActor
    func runRefreshSessionBlocking(
        _ event: RefreshSessionEvent,
        layoutWorkspaces shouldLayoutWorkspaces: Bool = true,
        optimisticallyPreLayoutWorkspaces: Bool = false,
    ) async throws {
        let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        try await $refreshSessionEvent.withValue(event) {
            try await $_isStartup.withValue(event.isStartup) {
                let nativeFocused = try await getNativeFocusedWindow()
                updateFocusCache(nativeFocused)

                if shouldLayoutWorkspaces && optimisticallyPreLayoutWorkspaces { try await layoutWorkspaces() }

                refreshModel()
                try await refresh()
                gcMonitors()

                updateTrayText()
                SecureInputPanel.shared.refresh()
                try await normalizeLayoutReason()
                if shouldLayoutWorkspaces { try await layoutWorkspaces() }
            }
        }
    }

    @MainActor
    func runLightSession<T>(
        _ event: RefreshSessionEvent,
        body: @MainActor () async throws -> T,
    ) async throws -> T {
        let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
        return try await $refreshSessionEvent.withValue(event) {
            try await $_isStartup.withValue(event.isStartup) {
                let nativeFocused = try await getNativeFocusedWindow()
                updateFocusCache(nativeFocused)
                let focusBefore = focus.windowOrNil

                refreshModel()
                let result = try await body()
                refreshModel()

                let focusAfter = focus.windowOrNil

                updateTrayText()
                SecureInputPanel.shared.refresh()
                try await layoutWorkspaces()
                if focusBefore != focusAfter {
                    focusAfter?.nativeFocus()
                }
                scheduleRefreshSession(event)
                return result
            }
        }
    }

    @MainActor
    func refreshModel() {
        garbageCollectUnusedWorkspaces()
        checkFocusCallbacks()
        normalizeAllWorkspaceContainers()
    }

    @MainActor
    private func refresh() async throws {
        // Garbage collect terminated apps and windows before working with all windows
        let mapping = try await MacApp.refreshAllAndGetAliveWindowIds(frontmostAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        let aliveWindowIds = mapping.values.flatMap { $0 }.toSet()

        for window in Window.allWindows {
            if !aliveWindowIds.contains(window.windowId) {
                window.garbageCollect(skipClosedWindowsCache: false)
            }
        }
        for (app, windowIds) in mapping {
            for windowId in windowIds {
                try await Window.getOrRegister(windowId: windowId, app: app)
            }
        }

        // Garbage collect workspaces after apps, because workspaces contain apps.
        garbageCollectUnusedWorkspaces()
    }

    @MainActor
    private func layoutWorkspaces() async throws {
        let monitors = monitors
        var monitorToOptimalHideCorner: [CGPoint: OptimalHideCorner] = [:]
        for monitor in monitors {
            let xOff = monitor.width * 0.1
            let yOff = monitor.height * 0.1
            // brc = bottomRightCorner
            let brc1 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: -yOff)
            let brc2 = monitor.rect.bottomRightCorner + CGPoint(x: -xOff, y: 2)
            let brc3 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: 2)

            // blc = bottomLeftCorner
            let blc1 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: -yOff)
            let blc2 = monitor.rect.bottomLeftCorner + CGPoint(x: xOff, y: 2)
            let blc3 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: 2)

            func contains(_ monitor: Monitor, _ point: CGPoint) -> Int { monitor.rect.contains(point) ? 1 : 0 }
            let important = 10

            let corner: OptimalHideCorner =
                monitors.sumOfInt { contains($0, blc1) + contains($0, blc2) + important * contains($0, blc3) } <
                monitors.sumOfInt { contains($0, brc1) + contains($0, brc2) + important * contains($0, brc3) }
                ? .bottomLeftCorner
                : .bottomRightCorner
            monitorToOptimalHideCorner[monitor.rect.topLeftCorner] = corner
        }

        // to reduce flicker, first unhide visible workspaces, then hide invisible ones
        for monitor in monitors {
            let workspace = monitor.activeWorkspace
            workspace.allLeafWindowsRecursive.forEach { $0.unhideFromCorner() }
            try await workspace.layoutWorkspace()
        }
        for workspace in allWorkspaces where !workspace.isVisible {
            let corner = monitorToOptimalHideCorner[workspace.workspaceMonitor.rect.topLeftCorner] ?? .bottomRightCorner
            for window in workspace.allLeafWindowsRecursive {
                try await window.hideInCorner(corner)
            }
        }
    }

    @MainActor
    private func normalizeAllWorkspaceContainers() {
        // Can't do it only for visible workspace because most of the commands support --window-id and --workspace flags
        for workspace in allWorkspaces {
            workspace.normalizeContainers()
        }
    }
}

@MainActor
func scheduleRefreshSession(
    _ event: RefreshSessionEvent,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) {
    currentSession.scheduleRefreshSession(event, optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces)
}

@MainActor
func runRefreshSessionBlocking(
    _ event: RefreshSessionEvent,
    layoutWorkspaces shouldLayoutWorkspaces: Bool = true,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) async throws {
    try await currentSession.runRefreshSessionBlocking(
        event,
        layoutWorkspaces: shouldLayoutWorkspaces,
        optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces,
    )
}

@MainActor
func runLightSession<T>(
    _ event: RefreshSessionEvent,
    body: @MainActor () async throws -> T,
) async throws -> T {
    try await currentSession.runLightSession(event, body: body)
}

@MainActor
func refreshModel() {
    currentSession.refreshModel()
}

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    let notif = notif as String
    Task { @MainActor in
        currentSession.scheduleRefreshSession(.ax(notif))
    }
}

enum OptimalHideCorner {
    case bottomLeftCorner, bottomRightCorner
}
