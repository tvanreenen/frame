public struct ListAppsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listApps,
        help: list_apps_help_generated,
        flags: [
            "--macos-native-hidden": boolFlag(\.macosHidden),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--count", "--json"],
        ],
    )

    public var macosHidden: Bool?
    public var outputOnlyCount: Bool = false
    public var json: Bool = false
}

public func parseListAppsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListAppsCmdArgs> {
    parseSpecificCmdArgs(ListAppsCmdArgs(rawArgs: args), args)
}
