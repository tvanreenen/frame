public struct ReloadConfigCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .reloadConfig,
        help: reload_config_help_generated,
        flags: [:],
        posArgs: [],
    )
}
