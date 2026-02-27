import Common

extension CmdArgs {
    func toCommand() -> any Command {
        let command: any Command
        switch Self.info.kind {
            case .addColumn:
                command = AddColumnCommand(args: self as! AddColumnCmdArgs)
            case .balanceSizes:
                command = BalanceSizesCommand(args: self as! BalanceSizesCmdArgs)
            case .config:
                command = ConfigCommand(args: self as! ConfigCmdArgs)
            case .debugWindows:
                command = DebugWindowsCommand(args: self as! DebugWindowsCmdArgs)
            case .enable:
                command = EnableCommand(args: self as! EnableCmdArgs)
            case .execAndForget:
                die("exec-and-forget is parsed separately")
            case .focus:
                command = FocusCommand(args: self as! FocusCmdArgs)
            case .focusBackAndForth:
                command = FocusBackAndForthCommand(args: self as! FocusBackAndForthCmdArgs)
            case .focusMonitor:
                command = FocusMonitorCommand(args: self as! FocusMonitorCmdArgs)
            case .fullscreen:
                command = FullscreenCommand(args: self as! FullscreenCmdArgs)
            case .layout:
                command = LayoutCommand(args: self as! LayoutCmdArgs)
            case .listApps:
                command = ListAppsCommand(args: self as! ListAppsCmdArgs)
            case .listExecEnvVars:
                command = ListExecEnvVarsCommand(args: self as! ListExecEnvVarsCmdArgs)
            case .listModes:
                command = ListModesCommand(args: self as! ListModesCmdArgs)
            case .listMonitors:
                command = ListMonitorsCommand(args: self as! ListMonitorsCmdArgs)
            case .listWindows:
                command = ListWindowsCommand(args: self as! ListWindowsCmdArgs)
            case .listWorkspaces:
                command = ListWorkspacesCommand(args: self as! ListWorkspacesCmdArgs)
            case .mode:
                command = ModeCommand(args: self as! ModeCmdArgs)
            case .move:
                command = MoveCommand(args: self as! MoveCmdArgs)
            case .moveMouse:
                command = MoveMouseCommand(args: self as! MoveMouseCmdArgs)
            case .moveNodeToMonitor:
                command = MoveNodeToMonitorCommand(args: self as! MoveNodeToMonitorCmdArgs)
            case .moveNodeToWorkspace:
                command = MoveNodeToWorkspaceCommand(args: self as! MoveNodeToWorkspaceCmdArgs)
            case .moveWorkspaceToMonitor:
                command = MoveWorkspaceToMonitorCommand(args: self as! MoveWorkspaceToMonitorCmdArgs)
            case .reloadConfig:
                command = ReloadConfigCommand(args: self as! ReloadConfigCmdArgs)
            case .removeColumn:
                command = RemoveColumnCommand(args: self as! RemoveColumnCmdArgs)
            case .resize:
                command = ResizeCommand(args: self as! ResizeCmdArgs)
            case .summonWorkspace:
                command = SummonWorkspaceCommand(args: self as! SummonWorkspaceCmdArgs)
            case .swap:
                command = SwapCommand(args: self as! SwapCmdArgs)
            case .triggerBinding:
                command = TriggerBindingCommand(args: self as! TriggerBindingCmdArgs)
            case .workspace:
                command = WorkspaceCommand(args: self as! WorkspaceCmdArgs)
            case .workspaceBackAndForth:
                command = WorkspaceBackAndForthCommand(args: self as! WorkspaceBackAndForthCmdArgs)
        }
        check(command.info == Self.info)
        return command
    }
}
