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
    return switch try await app.getAxUiElementWindowType(windowId: windowId, windowLevel: windowLevel) {
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

@MainActor
func tryOnWindowDetected(_ window: Window) async throws {
    guard let parent = window.parent else { return }
    switch parent.cases {
        case .tilingContainer, .workspace, .macosMinimizedWindowsContainer,
             .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
            try await onWindowDetected(window)
        case .macosPopupWindowsContainer:
            break
    }
}

@MainActor
private func onWindowDetected(_ window: Window) async throws {
    for callback in runtimeContext.config.onWindowDetected where try await callback.matches(window) {
        _ = try await callback.run.runCmdSeq(.defaultEnv.copy(\.windowId, window.windowId), .emptyStdin)
        if !callback.checkFurtherCallbacks {
            return
        }
    }
}

extension WindowDetectedCallback {
    @MainActor
    func matches(_ window: Window) async throws -> Bool {
        if let startupMatcher = matcher.duringAppStartup, startupMatcher != isStartup {
            return false
        }
        if let regex = matcher.windowTitleRegexSubstring, !(try await window.title).contains(regex) {
            return false
        }
        if let appId = matcher.appId, appId != window.app.rawAppBundleId {
            return false
        }
        if let regex = matcher.appNameRegexSubstring, !(window.app.name ?? "").contains(regex) {
            return false
        }
        if let workspace = matcher.workspace, workspace != window.nodeWorkspace?.name {
            return false
        }
        return true
    }
}
