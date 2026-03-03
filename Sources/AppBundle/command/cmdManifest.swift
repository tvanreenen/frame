import Common

private protocol CommandFactoryArgs: CmdArgs {
    func eraseToCommand() -> any Command
}

extension CmdArgs {
    func toCommand() -> any Command {
        guard let factory = self as? any CommandFactoryArgs else {
            die("No command factory found for '\(Self.info.kind.rawValue)'")
        }
        let command = factory.eraseToCommand()
        check(command.info == Self.info)
        return command
    }
}

extension AddColumnCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { AddColumnCommand(args: self) } }
extension BalanceSizesCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { BalanceSizesCommand(args: self) } }
extension DoctorCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { DoctorCommand(args: self) } }
extension FocusCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { FocusCommand(args: self) } }
extension FocusMonitorCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { FocusMonitorCommand(args: self) } }
extension FullscreenCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { FullscreenCommand(args: self) } }
extension LayoutCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { LayoutCommand(args: self) } }
extension ListAppsCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { ListAppsCommand(args: self) } }
extension ListMonitorsCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { ListMonitorsCommand(args: self) } }
extension ListWindowsCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { ListWindowsCommand(args: self) } }
extension ListWorkspacesCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { ListWorkspacesCommand(args: self) } }
extension MoveCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { MoveCommand(args: self) } }
extension MoveMouseCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { MoveMouseCommand(args: self) } }
extension MoveNodeToWorkspaceCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { MoveNodeToWorkspaceCommand(args: self) } }
extension ReloadConfigCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { ReloadConfigCommand(args: self) } }
extension RemoveColumnCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { RemoveColumnCommand(args: self) } }
extension ResizeCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { ResizeCommand(args: self) } }
extension WorkspaceCmdArgs: CommandFactoryArgs { func eraseToCommand() -> any Command { WorkspaceCommand(args: self) } }
