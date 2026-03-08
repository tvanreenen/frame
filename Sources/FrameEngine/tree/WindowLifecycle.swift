import AppKit

extension Window {
    @MainActor
    func relayoutWindow(on workspace: Workspace, forceTile: Bool = false) async throws {
        let data = forceTile
            ? unbindAndGetBindingDataForNewTilingWindow(on: workspace, window: self)
            : try await unbindAndGetBindingDataForNewWindow(windowId, app, workspace, window: self)
        bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
    }
}

// The function is private because it's unsafe. It leaves the window in unbound state
@MainActor
func unbindAndGetBindingDataForNewWindow(
    _ windowId: UInt32,
    _ app: any WindowPlatformApp,
    _ workspace: Workspace,
    window: Window?,
) async throws -> BindingData {
    let windowType = try await Window.resolveWindowType(windowId: windowId, app: app)

    return switch windowType {
        case .popup: BindingData(parent: popupWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        case .dialog: BindingData(parent: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        case .window: unbindAndGetBindingDataForNewTilingWindow(on: workspace, window: window)
    }
}

// The function is private because it's unsafe. It leaves the window in unbound state
@MainActor
func unbindAndGetBindingDataForNewTilingWindow(on workspace: Workspace, window: Window?) -> BindingData {
    window?.unbindFromParent() // It's important to unbind to get correct data from below
    return workspace.newTilingWindowBindingData()
}
