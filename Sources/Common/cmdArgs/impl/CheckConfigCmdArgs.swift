public struct CheckConfigCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .checkConfig,
        help: check_config_help_generated,
        flags: [:],
        posArgs: [],
    )
}
