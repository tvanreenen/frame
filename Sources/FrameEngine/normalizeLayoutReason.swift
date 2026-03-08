@MainActor
func normalizeLayoutReason() async throws {
    for workspace in Workspace.all {
        let windows: [Window] = workspace.allLeafWindowsRecursive
        try await _normalizeLayoutReason(workspace: workspace, windows: windows)
    }
    try await _normalizeLayoutReason(workspace: focus.workspace, windows: nativeMinimizedWindowsContainer.children.filterIsInstance(of: Window.self))
    try await validateStillPopups()
}

@MainActor
private func validateStillPopups() async throws {
    for node in popupWindowsContainer.children {
        guard let popup = node as? Window else { continue }
        if try await popup.getResolvedAxUiElementWindowType() != .popup {
            try await popup.relayoutWindow(on: focus.workspace)
        }
    }
}

@MainActor
private func _normalizeLayoutReason(workspace: Workspace, windows: [Window]) async throws {
    for window in windows {
        let isNativeFullscreen = try await window.isNativeFullscreen
        let isNativeMinimized = try await (!isNativeFullscreen).andAsync { @MainActor @Sendable in try await window.isNativeMinimized }
        let isHiddenAppWindow = !isNativeFullscreen && !isNativeMinimized && window.app.isHidden
        switch window.layoutReason {
            case .standard:
                guard let parent = window.parent else { continue }
                if isNativeFullscreen {
                    window.layoutReason = .platformDisplaced(previousPlacement: parent.recoveryPlacement)
                    window.bind(to: workspace.nativeFullscreenWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
                } else if isNativeMinimized {
                    window.layoutReason = .platformDisplaced(previousPlacement: parent.recoveryPlacement)
                    window.bind(to: nativeMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
                } else if isHiddenAppWindow {
                    window.layoutReason = .platformDisplaced(previousPlacement: parent.recoveryPlacement)
                    window.bind(to: workspace.hiddenAppWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
                }
            case .platformDisplaced(let previousPlacement):
                if !isNativeFullscreen && !isNativeMinimized && !isHiddenAppWindow {
                    try await restoreFromPlatformDisplacement(window: window, previousPlacement: previousPlacement, workspace: workspace)
                }
        }
    }
}

@MainActor
func restoreFromPlatformDisplacement(window: Window, previousPlacement: PreviousWindowPlacement, workspace: Workspace) async throws {
    window.layoutReason = .standard
    switch previousPlacement {
        case .floating:
            window.bindAsFloatingWindow(to: workspace)
        case .tiled:
            try await window.relayoutWindow(on: workspace, forceTile: true)
        case .reclassify:
            try await window.relayoutWindow(on: workspace)
    }
}

extension NonLeafTreeNode {
    var recoveryPlacement: PreviousWindowPlacement {
        if self is Workspace { return .floating }
        if self is Column { return .tiled }
        return .reclassify
    }
}
