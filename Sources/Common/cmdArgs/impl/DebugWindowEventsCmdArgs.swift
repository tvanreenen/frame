public struct DebugWindowEventsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .debugWindowEvents,
        help: debug_window_events_help_generated,
        flags: [:],
        posArgs: [],
    )
}

public func parseDebugWindowEventsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<DebugWindowEventsCmdArgs> {
    parseSpecificCmdArgs(DebugWindowEventsCmdArgs(rawArgs: args), args)
}
