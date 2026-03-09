package struct FrozenWorld {
    let workspaces: [FrozenWorkspace]
    let monitors: [FrozenMonitor]
    let windowIds: Set<UInt32>
}

@MainActor
func collectAllWindowIds(workspace: Workspace) -> [UInt32] {
    workspace.nativeFullscreenWindowsContainer.children.map { ($0 as! Window).windowId } +
        workspace.hiddenAppWindowsContainer.children.map { ($0 as! Window).windowId } +
        workspace.columns.flatMap { $0.children.compactMap { ($0 as? Window)?.windowId } }
}
