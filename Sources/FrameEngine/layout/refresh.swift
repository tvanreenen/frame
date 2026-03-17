import Common
import Foundation

package struct AppWindowBindingSnapshot: Equatable {
    package let frameWindowId: FrameWindowId
    package let platformWindowId: UInt32
    package let appPid: Int32
}

package struct PlannedWindowRebind: Equatable {
    package let frameWindowId: FrameWindowId
    package let expectedPlatformWindowId: UInt32
    package let newPlatformWindowId: UInt32
    package let lastKnownSize: CGSize?
}

package struct PlannedWindowGarbageCollection: Equatable {
    package let frameWindowId: FrameWindowId
    package let expectedPlatformWindowId: UInt32
}

package struct AppRefreshPlan: Equatable {
    package let snapshotPlatformWindowIds: [UInt32]
    package let unmatchedFrameWindowIds: [FrameWindowId]
    package let unmatchedWindowIds: [UInt32]
    package let focusedWindowId: UInt32?
    package let replacementFrameWindowId: FrameWindowId?
    package let replacementWindowId: UInt32?
    package let replacementReason: String
    package let rebind: PlannedWindowRebind?
    package let garbageCollections: [PlannedWindowGarbageCollection]
    package let registerWindowIds: [UInt32]
}

extension AppSession {
    @MainActor package func scheduleRefreshSession(
        _ event: RefreshSessionEvent,
        optimisticallyPreLayoutWorkspaces: Bool = false,
    ) {
        activeRefreshTask?.cancel()
        activeRefreshTask = Task { @MainActor in
            try checkCancellation()
            try await runRefreshSessionBlocking(event, optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces)
        }
    }

    @MainActor package func runRefreshSessionBlocking(
        _ event: RefreshSessionEvent,
        layoutWorkspaces shouldLayoutWorkspaces: Bool = true,
        optimisticallyPreLayoutWorkspaces: Bool = false,
    ) async throws {
        let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        try await $refreshSessionEvent.withValue(event) {
            try await $_isStartup.withValue(event.isStartup) {
                let nativeFocused = try await platformServices.nativeFocusedWindow()
                updateFocusCache(nativeFocused)

                if shouldLayoutWorkspaces && optimisticallyPreLayoutWorkspaces { try await layoutWorkspaces() }

                refreshModel()
                try await refresh()
                let nativeFocusedAfterRefresh = try await platformServices.nativeFocusedWindow()
                updateFocusCache(nativeFocusedAfterRefresh)
                refreshModel()
                gcMonitors()

                platformServices.syncUiState(self)
                try await normalizeLayoutReason()
                if shouldLayoutWorkspaces { try await layoutWorkspaces() }
            }
        }
    }

    @MainActor package func runLightSession<T>(
        _ event: RefreshSessionEvent,
        body: @MainActor () async throws -> T,
    ) async throws -> T {
        let state = signposter.beginInterval(#function, "event: \(event) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
        return try await $refreshSessionEvent.withValue(event) {
            try await $_isStartup.withValue(event.isStartup) {
                let nativeFocused = try await platformServices.nativeFocusedWindow()
                updateFocusCache(nativeFocused)
                let focusBefore = focus.windowOrNil

                refreshModel()
                let result = try await body()
                refreshModel()

                let focusAfter = focus.windowOrNil

                platformServices.syncUiState(self)
                try await layoutWorkspaces()
                if focusBefore != focusAfter {
                    focusAfter?.nativeFocus()
                }
                scheduleRefreshSession(event)
                return result
            }
        }
    }

    @MainActor package func refreshModel() {
        garbageCollectUnusedWorkspaces()
        checkFocusCallbacks()
        normalizeAllWorkspaceContainers()
    }

    @MainActor
    private func refresh() async throws {
        let mapping = try await platformServices.refreshPlatformApps(platformServices.frontmostAppBundleId())
        let processedPids = mapping.map(\.app.pid).toSet()
        let windowBindingSnapshotsByPid = Dictionary(grouping: Window.allWindows.map {
            AppWindowBindingSnapshot(
                frameWindowId: $0.windowId,
                platformWindowId: $0.platformWindowId,
                appPid: $0.app.pid,
            )
        }, by: \.appPid)

        for (app, snapshot) in mapping {
            let bindingSnapshots = windowBindingSnapshotsByPid[app.pid] ?? []
            let plan = try await makeAppRefreshPlan(app: app, snapshot: snapshot, bindingSnapshots: bindingSnapshots)
            try await applyAppRefreshPlan(plan, app: app)
        }

        for window in Window.allWindows where !processedPids.contains(window.app.pid) {
            window.garbageCollect(skipClosedWindowsCache: false)
        }

        // Garbage collect workspaces after apps, because workspaces contain apps.
        garbageCollectUnusedWorkspaces()
    }

    @MainActor
    package func makeAppRefreshPlan(
        app: any WindowPlatformApp,
        snapshot: PlatformAppRefreshSnapshot,
        bindingSnapshots: [AppWindowBindingSnapshot],
    ) async throws -> AppRefreshPlan {
        let windowIds = snapshot.windowIds
        let windowIdSet = windowIds.toSet()
        let snapshotPlatformWindowIds = bindingSnapshots.map(\.platformWindowId)

        let unmatchedBindingSnapshots = bindingSnapshots.filter { !windowIdSet.contains($0.platformWindowId) }
        let unmatchedWindowIds = windowIds.filter { windowId in
            !bindingSnapshots.contains { $0.platformWindowId == windowId }
        }
        let replacementFrameWindowId = unmatchedBindingSnapshots.singleOrNil()?.frameWindowId
        let candidateReplacementWindowId =
            unmatchedBindingSnapshots.count == 1
            ? try await replacementPlatformWindowId(
                for: unmatchedBindingSnapshots[0],
                candidates: unmatchedWindowIds,
                app: app,
                focusedWindowId: snapshot.focusedWindowId,
            )
            : nil

        let replacementReason: String
        if unmatchedBindingSnapshots.isEmpty && unmatchedWindowIds.isEmpty {
            replacementReason = "exact_matches_only"
        } else if unmatchedBindingSnapshots.count != 1 {
            replacementReason = "unmatched_windows_count_\(unmatchedBindingSnapshots.count)"
        } else if candidateReplacementWindowId == nil {
            replacementReason = "no_replacement_candidate"
        } else {
            replacementReason = "rebind"
        }

        let rebind: PlannedWindowRebind?
        let garbageCollections: [PlannedWindowGarbageCollection]
        let registerWindowIds: [UInt32]
        if replacementReason == "rebind",
            let replacementWindowId = candidateReplacementWindowId,
            let reboundSnapshot = unmatchedBindingSnapshots.singleOrNil()
        {
            let rect = try await app.getWindowRect(windowId: replacementWindowId)
            rebind = PlannedWindowRebind(
                frameWindowId: reboundSnapshot.frameWindowId,
                expectedPlatformWindowId: reboundSnapshot.platformWindowId,
                newPlatformWindowId: replacementWindowId,
                lastKnownSize: rect?.size,
            )
            garbageCollections = []
            registerWindowIds = unmatchedWindowIds.filter { $0 != replacementWindowId }
        } else {
            rebind = nil
            garbageCollections = unmatchedBindingSnapshots.map {
                PlannedWindowGarbageCollection(
                    frameWindowId: $0.frameWindowId,
                    expectedPlatformWindowId: $0.platformWindowId,
                )
            }
            registerWindowIds = unmatchedWindowIds
        }

        return AppRefreshPlan(
            snapshotPlatformWindowIds: snapshotPlatformWindowIds,
            unmatchedFrameWindowIds: unmatchedBindingSnapshots.map(\.frameWindowId),
            unmatchedWindowIds: unmatchedWindowIds,
            focusedWindowId: snapshot.focusedWindowId,
            replacementFrameWindowId: replacementFrameWindowId,
            replacementWindowId: candidateReplacementWindowId,
            replacementReason: replacementReason,
            rebind: rebind,
            garbageCollections: garbageCollections,
            registerWindowIds: registerWindowIds,
        )
    }

    @MainActor
    package func applyAppRefreshPlan(
        _ plan: AppRefreshPlan,
        app: any WindowPlatformApp,
    ) async throws {
        currentSession.windowEventsDiagnosticsLogger.logRefreshReconcile(
            bundleId: app.rawAppBundleId,
            pid: app.pid,
            existingPlatformWindowIds: plan.snapshotPlatformWindowIds,
            unmatchedFrameWindowIds: plan.unmatchedFrameWindowIds.map(\.description),
            unmatchedWindowIds: plan.unmatchedWindowIds,
            focusedWindowId: plan.focusedWindowId,
            replacementFrameWindowId: plan.replacementFrameWindowId,
            replacementWindowId: plan.replacementWindowId,
            replacementReason: plan.replacementReason,
            applyResult: nil,
        )
        try checkCancellation()
        if let applyResult = validateAppRefreshPlan(plan) {
            currentSession.windowEventsDiagnosticsLogger.logRefreshReconcile(
                bundleId: app.rawAppBundleId,
                pid: app.pid,
                existingPlatformWindowIds: plan.snapshotPlatformWindowIds,
                unmatchedFrameWindowIds: plan.unmatchedFrameWindowIds.map(\.description),
                unmatchedWindowIds: plan.unmatchedWindowIds,
                focusedWindowId: plan.focusedWindowId,
                replacementFrameWindowId: plan.replacementFrameWindowId,
                replacementWindowId: plan.replacementWindowId,
                replacementReason: plan.replacementReason,
                applyResult: applyResult,
            )
            return
        }

        if let rebind = plan.rebind {
            Window.get(byId: rebind.frameWindowId)?.rebind(
                toPlatformWindowId: rebind.newPlatformWindowId,
                lastKnownSize: rebind.lastKnownSize,
            )
        }
        for garbageCollection in plan.garbageCollections {
            Window.get(byId: garbageCollection.frameWindowId)?.garbageCollect(skipClosedWindowsCache: false)
        }
        for windowId in plan.registerWindowIds {
            try checkCancellation()
            _ = try await Window.getOrRegister(windowId: windowId, app: app)
        }
    }

    @MainActor
    private func validateAppRefreshPlan(_ plan: AppRefreshPlan) -> String? {
        if let rebind = plan.rebind {
            guard let window = Window.get(byId: rebind.frameWindowId),
                window.platformWindowId == rebind.expectedPlatformWindowId,
                Window.get(byPlatformWindowId: rebind.newPlatformWindowId) == nil
            else {
                return "snapshot_drift"
            }
        }
        for garbageCollection in plan.garbageCollections {
            guard let window = Window.get(byId: garbageCollection.frameWindowId),
                window.platformWindowId == garbageCollection.expectedPlatformWindowId
            else {
                return "snapshot_drift"
            }
        }
        for windowId in plan.registerWindowIds where Window.get(byPlatformWindowId: windowId) != nil {
            return "snapshot_drift"
        }
        return nil
    }

    @MainActor
    private func replacementPlatformWindowId(
        for window: AppWindowBindingSnapshot,
        candidates: [UInt32],
        app: any WindowPlatformApp,
        focusedWindowId: UInt32?,
    ) async throws -> UInt32? {
        if candidates.count == 1 {
            return candidates.singleOrNil()
        }
        guard let currentRect = try await app.getWindowRect(windowId: window.platformWindowId) else { return nil }

        var matchingCandidates: [UInt32] = []
        for candidate in candidates {
            if let candidateRect = try await app.getWindowRect(windowId: candidate),
                candidateRect.topLeftX == currentRect.topLeftX,
                candidateRect.topLeftY == currentRect.topLeftY,
                candidateRect.width == currentRect.width,
                candidateRect.height == currentRect.height
            {
                matchingCandidates.append(candidate)
            }
        }
        if matchingCandidates.count == 1 {
            return matchingCandidates.singleOrNil()
        }
        if let focusedWindowId, matchingCandidates.count > 1 {
            return matchingCandidates.filter { $0 == focusedWindowId }.singleOrNil()
        }
        return nil
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

@MainActor package func scheduleRefreshSession(
    _ event: RefreshSessionEvent,
    optimisticallyPreLayoutWorkspaces: Bool = false,
) {
    currentSession.scheduleRefreshSession(event, optimisticallyPreLayoutWorkspaces: optimisticallyPreLayoutWorkspaces)
}

@MainActor package func runRefreshSessionBlocking(
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

@MainActor package func runLightSession<T>(
    _ event: RefreshSessionEvent,
    body: @MainActor () async throws -> T,
) async throws -> T {
    try await currentSession.runLightSession(event, body: body)
}

@MainActor package func refreshModel() {
    currentSession.refreshModel()
}

package enum OptimalHideCorner {
    case bottomLeftCorner, bottomRightCorner
}
