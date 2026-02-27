public struct ListMonitorsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listMonitors,
        help: list_monitors_help_generated,
        flags: [
            "--focused": boolFlag(\.focused),
            "--mouse": boolFlag(\.mouse),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--count", "--json"],
        ],
    )

    public var focused: Bool?
    public var mouse: Bool?
    public var outputOnlyCount: Bool = false
    public var json: Bool = false
}

public func parseListMonitorsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListMonitorsCmdArgs> {
    parseSpecificCmdArgs(ListMonitorsCmdArgs(rawArgs: args), args)
}
