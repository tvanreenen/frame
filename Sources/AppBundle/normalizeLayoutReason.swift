@MainActor
func normalizeLayoutReason() async throws {
    for workspace in Workspace.all {
        let windows: [Window] = workspace.allLeafWindowsRecursive
        try await _normalizeLayoutReason(workspace: workspace, windows: windows)
    }
    try await _normalizeLayoutReason(workspace: focus.workspace, windows: macosMinimizedWindowsContainer.children.filterIsInstance(of: Window.self))
    try await validateStillPopups()
}

@MainActor
private func validateStillPopups() async throws {
    for node in macosPopupWindowsContainer.children {
        guard let popup = node as? Window else { continue }
        let windowLevel = getWindowLevel(for: popup.windowId)
        if try await popup.getResolvedAxUiElementWindowType(windowLevel) != .popup {
            try await popup.relayoutWindow(on: focus.workspace)
        }
    }
}

@MainActor
private func _normalizeLayoutReason(workspace: Workspace, windows: [Window]) async throws {
    for window in windows {
        let isMacosFullscreen = try await window.isMacosFullscreen
        let isMacosMinimized = try await (!isMacosFullscreen).andAsync { @MainActor @Sendable in try await window.isMacosMinimized }
        let isMacosWindowOfHiddenApp = !isMacosFullscreen && !isMacosMinimized && window.app.isHidden
        switch window.layoutReason {
            case .standard:
                guard let parent = window.parent else { continue }
                if isMacosFullscreen {
                    window.layoutReason = .macos(previousPlacement: parent.macOsRecoveryPlacement)
                    window.bind(to: workspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
                } else if isMacosMinimized {
                    window.layoutReason = .macos(previousPlacement: parent.macOsRecoveryPlacement)
                    window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
                } else if isMacosWindowOfHiddenApp {
                    window.layoutReason = .macos(previousPlacement: parent.macOsRecoveryPlacement)
                    window.bind(to: workspace.macOsNativeHiddenAppsWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
                }
            case .macos(let previousPlacement):
                if !isMacosFullscreen && !isMacosMinimized && !isMacosWindowOfHiddenApp {
                    try await exitMacOsNativeUnconventionalState(window: window, previousPlacement: previousPlacement, workspace: workspace)
                }
        }
    }
}

@MainActor
func exitMacOsNativeUnconventionalState(window: Window, previousPlacement: PreviousMacOsWindowPlacement, workspace: Workspace) async throws {
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

extension NonLeafTreeNodeObject {
    var macOsRecoveryPlacement: PreviousMacOsWindowPlacement {
        switch cases {
            case .workspace:
                .floating
            case .tilingContainer:
                .tiled
            case .macosPopupWindowsContainer,
                 .macosMinimizedWindowsContainer,
                 .macosFullscreenWindowsContainer,
                 .macosHiddenAppsWindowsContainer:
                .reclassify
        }
    }
}
