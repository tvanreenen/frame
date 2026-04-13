import Foundation

extension Window {
    @MainActor
    func relayoutWindow(on workspace: Workspace, forceTile: Bool = false) async throws {
        let data = forceTile
            ? unbindAndGetBindingDataForNewTilingWindow(on: workspace, window: self)
            : try await unbindAndGetBindingDataForNewWindow(platformWindowId, app, workspace, placementDecision: nil, window: self)
        bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
    }
}

// The function is private because it's unsafe. It leaves the window in unbound state
@MainActor
func unbindAndGetBindingDataForNewWindow(
    _ windowId: UInt32,
    _ app: any WindowPlatformApp,
    _ workspace: Workspace,
    placementDecision: WindowPlacementDecision?,
    window: Window?,
) async throws -> BindingData {
    let resolvedDecision = if let placementDecision {
        placementDecision
    } else {
        try await Window.resolvePlacementDecision(windowId: windowId, app: app)
    }
    let windowType = resolvedDecision.placementKind

    return switch windowType {
        case .excluded: BindingData(parent: excludedWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        case .tiling: unbindAndGetBindingDataForNewTilingWindow(on: workspace, window: window)
    }
}

// The function is private because it's unsafe. It leaves the window in unbound state
@MainActor
func unbindAndGetBindingDataForNewTilingWindow(on workspace: Workspace, window: Window?) -> BindingData {
    window?.unbindFromParent() // It's important to unbind to get correct data from below
    return workspace.newTilingWindowBindingData()
}
