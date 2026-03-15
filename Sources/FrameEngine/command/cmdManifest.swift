import Common

package protocol CommandFactoryArgs: CmdArgs {
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

extension AddColumnCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { AddColumnCommand(args: self) } }
extension BalanceSizesCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { BalanceSizesCommand(args: self) } }
extension DebugWindowEventsCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { DebugWindowEventsCommand(args: self) } }
extension FocusCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { FocusCommand(args: self) } }
extension FocusMonitorCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { FocusMonitorCommand(args: self) } }
extension FullscreenCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { FullscreenCommand(args: self) } }
extension MoveCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { MoveCommand(args: self) } }
extension MoveNodeToWorkspaceCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { MoveNodeToWorkspaceCommand(args: self) } }
extension RemoveColumnCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { RemoveColumnCommand(args: self) } }
extension ResizeCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { ResizeCommand(args: self) } }
extension WorkspaceCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { WorkspaceCommand(args: self) } }
