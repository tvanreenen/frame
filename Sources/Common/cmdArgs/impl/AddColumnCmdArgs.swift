public struct AddColumnCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .addColumn,
        help: add_column_help_generated,
        flags: [:],
        posArgs: [],
    )
}
