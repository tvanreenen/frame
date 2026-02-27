import Common

extension CmdArgs {
    func toCommand() -> any Command {
        let command: any Command
        switch Self.info.kind {
            case .addColumn:
                command = AddColumnCommand(args: self as! AddColumnCmdArgs)
            case .balanceSizes:
                command = BalanceSizesCommand(args: self as! BalanceSizesCmdArgs)
            case .enable:
                command = EnableCommand(args: self as! EnableCmdArgs)
            case .focus:
                command = FocusCommand(args: self as! FocusCmdArgs)
            case .focusMonitor:
                command = FocusMonitorCommand(args: self as! FocusMonitorCmdArgs)
            case .fullscreen:
                command = FullscreenCommand(args: self as! FullscreenCmdArgs)
            case .layout:
                command = LayoutCommand(args: self as! LayoutCmdArgs)
            case .listApps:
                command = ListAppsCommand(args: self as! ListAppsCmdArgs)
            case .listMonitors:
                command = ListMonitorsCommand(args: self as! ListMonitorsCmdArgs)
            case .listWindows:
                command = ListWindowsCommand(args: self as! ListWindowsCmdArgs)
            case .listWorkspaces:
                command = ListWorkspacesCommand(args: self as! ListWorkspacesCmdArgs)
            case .move:
                command = MoveCommand(args: self as! MoveCmdArgs)
            case .moveMouse:
                command = MoveMouseCommand(args: self as! MoveMouseCmdArgs)
            case .moveNodeToWorkspace:
                command = MoveNodeToWorkspaceCommand(args: self as! MoveNodeToWorkspaceCmdArgs)
            case .reloadConfig:
                command = ReloadConfigCommand(args: self as! ReloadConfigCmdArgs)
            case .removeColumn:
                command = RemoveColumnCommand(args: self as! RemoveColumnCmdArgs)
            case .resize:
                command = ResizeCommand(args: self as! ResizeCmdArgs)
            case .workspace:
                command = WorkspaceCommand(args: self as! WorkspaceCmdArgs)
        }
        check(command.info == Self.info)
        return command
    }
}
