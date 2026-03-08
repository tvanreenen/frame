import Common
import FrameEngine

extension DoctorCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { DoctorCommand(args: self) } }
extension ListAppsCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { ListAppsCommand(args: self) } }
extension ListMonitorsCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { ListMonitorsCommand(args: self) } }
extension ListWindowsCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { ListWindowsCommand(args: self) } }
extension ListWorkspacesCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { ListWorkspacesCommand(args: self) } }
extension MoveMouseCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { MoveMouseCommand(args: self) } }
extension ReloadConfigCmdArgs: CommandFactoryArgs { package func eraseToCommand() -> any Command { ReloadConfigCommand(args: self) } }
