public struct RemoveColumnCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .removeColumn,
        allowInConfig: true,
        help: remove_column_help_generated,
        flags: [:],
        posArgs: [],
    )
}
