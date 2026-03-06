struct FrozenWorld {
    let workspaces: [FrozenWorkspace]
    let monitors: [FrozenMonitor]
    let windowIds: Set<UInt32>
}

@MainActor
func collectAllWindowIds(workspace: Workspace) -> [UInt32] {
    workspace.floatingWindows.map { $0.windowId } +
        workspace.macOsNativeFullscreenWindowsContainer.children.map { ($0 as! Window).windowId } +
        workspace.macOsNativeHiddenAppsWindowsContainer.children.map { ($0 as! Window).windowId } +
        collectAllWindowIdsRecursive(workspace.rootTilingContainer)
}

func collectAllWindowIdsRecursive(_ node: TreeNode) -> [UInt32] {
    if let window = node as? Window {
        return [window.windowId]
    }
    if let container = node as? Column {
        return container.children.reduce(into: [UInt32]()) { partialResult, elem in
            partialResult += collectAllWindowIdsRecursive(elem)
        }
    }
    return []
}
