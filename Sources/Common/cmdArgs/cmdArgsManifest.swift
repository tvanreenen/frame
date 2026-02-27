public enum CmdKind: String, CaseIterable, Equatable, Sendable {
    // Sorted

    case addColumn = "add-column"
    case balanceSizes = "balance-sizes"
    case enable
    case execAndForget = "exec-and-forget"
    case focus
    case focusMonitor = "focus-monitor"
    case fullscreen
    case layout
    case listApps = "list-apps"
    case listExecEnvVars = "list-exec-env-vars"
    case listMonitors = "list-monitors"
    case listWindows = "list-windows"
    case listWorkspaces = "list-workspaces"
    case move = "move"
    case moveMouse = "move-mouse"
    case moveNodeToWorkspace = "move-node-to-workspace"
    case reloadConfig = "reload-config"
    case removeColumn = "remove-column"
    case resize
    case workspace
}

func initSubcommands() -> [String: any SubCommandParserProtocol] {
    var result: [String: any SubCommandParserProtocol] = [:]
    for kind in CmdKind.allCases {
        switch kind {
            case .addColumn:
                result[kind.rawValue] = SubCommandParser(AddColumnCmdArgs.init)
            case .balanceSizes:
                result[kind.rawValue] = SubCommandParser(BalanceSizesCmdArgs.init)
            case .enable:
                result[kind.rawValue] = SubCommandParser(parseEnableCmdArgs)
            case .execAndForget:
                break // exec-and-forget is parsed separately
            case .focus:
                result[kind.rawValue] = SubCommandParser(parseFocusCmdArgs)
            case .focusMonitor:
                result[kind.rawValue] = SubCommandParser(parseFocusMonitorCmdArgs)
            case .fullscreen:
                result[kind.rawValue] = SubCommandParser(parseFullscreenCmdArgs)
            case .layout:
                result[kind.rawValue] = SubCommandParser(parseLayoutCmdArgs)
            case .listApps:
                result[kind.rawValue] = SubCommandParser(parseListAppsCmdArgs)
            case .listExecEnvVars:
                result[kind.rawValue] = SubCommandParser(ListExecEnvVarsCmdArgs.init)
            case .listMonitors:
                result[kind.rawValue] = SubCommandParser(parseListMonitorsCmdArgs)
            case .listWindows:
                result[kind.rawValue] = SubCommandParser(parseListWindowsCmdArgs)
            case .listWorkspaces:
                result[kind.rawValue] = SubCommandParser(parseListWorkspacesCmdArgs)
            case .move:
                result[kind.rawValue] = SubCommandParser(parseMoveCmdArgs)
            case .moveMouse:
                result[kind.rawValue] = SubCommandParser(parseMoveMouseCmdArgs)
            case .moveNodeToWorkspace:
                result[kind.rawValue] = SubCommandParser(parseMoveNodeToWorkspaceCmdArgs)
            case .reloadConfig:
                result[kind.rawValue] = SubCommandParser(ReloadConfigCmdArgs.init)
            case .removeColumn:
                result[kind.rawValue] = SubCommandParser(RemoveColumnCmdArgs.init)
            case .resize:
                result[kind.rawValue] = SubCommandParser(parseResizeCmdArgs)
            case .workspace:
                result[kind.rawValue] = SubCommandParser(parseWorkspaceCmdArgs)
        }
    }
    return result
}
