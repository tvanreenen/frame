import AppKit

extension Window {
    @MainActor
    func relayoutWindow(on workspace: Workspace, forceTile: Bool = false) async throws {
        let data = forceTile
            ? unbindAndGetBindingDataForNewTilingWindow(workspace, window: self)
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
    let windowLevel = getWindowLevel(for: windowId)
    let windowType = try await Window.resolveWindowType(windowId: windowId, app: app, windowLevel: windowLevel)

    return switch windowType {
        case .popup: BindingData(parent: macosPopupWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        case .dialog: BindingData(parent: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        case .window: unbindAndGetBindingDataForNewTilingWindow(workspace, window: window)
    }
}

// The function is private because it's unsafe. It leaves the window in unbound state
@MainActor
func unbindAndGetBindingDataForNewTilingWindow(_ workspace: Workspace, window: Window?) -> BindingData {
    window?.unbindFromParent() // It's important to unbind to get correct data from below
    // Place new window into the focused column, or create one if the workspace is empty.
    if let column = workspace.focusedColumn {
        return BindingData(
            parent: column,
            adaptiveWeight: WEIGHT_AUTO,
            index: INDEX_BIND_LAST,
        )
    } else {
        let column = workspace.addColumn(after: nil)
        return BindingData(
            parent: column,
            adaptiveWeight: WEIGHT_AUTO,
            index: INDEX_BIND_LAST,
        )
    }
}
