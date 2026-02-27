private let workspace = "<workspace>"
private let workspaces = "\(workspace)..."

public struct ListWindowsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWindows,
        help: list_windows_help_generated,
        flags: [
            "--all": trueBoolFlag(\.all),

            // Filtering flags
            "--focused": trueBoolFlag(\.filteringOptions.focused),
            "--monitor": SubArgParser(\.filteringOptions.monitors, parseMonitorIds),
            "--workspace": SubArgParser(\.filteringOptions.workspaces, parseWorkspaces),
            "--pid": singleValueSubArgParser(\.filteringOptions.pidFilter, "<pid>", Int32.init),
            "--app-bundle-id": singleValueSubArgParser(\.filteringOptions.appIdFilter, "<app-bundle-id>") { $0 },
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--all", "--focused", "--workspace"],
            ["--all", "--focused", "--monitor"],
            ["--count", "--json"],
        ],
    )

    fileprivate var all: Bool = false // ALIAS

    public var filteringOptions = FilteringOptions()
    public var outputOnlyCount: Bool = false
    public var json: Bool = false

    public struct FilteringOptions: ConvenienceCopyable, Equatable, Sendable {
        public var monitors: [MonitorId] = []
        public var focused: Bool = false
        public var workspaces: [WorkspaceFilter] = []
        public var pidFilter: Int32?
        public var appIdFilter: String?
    }
}

public func parseListWindowsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListWindowsCmdArgs> {
    let args = args.map { $0 == "--app-id" ? "--app-bundle-id" : $0 }.slice // Compatibility
    return parseSpecificCmdArgs(ListWindowsCmdArgs(commonState: .init(args)), args)
        .filter("Mandatory option is not specified (--focused|--all|--monitor|--workspace)") { raw in
            raw.filteringOptions.focused || raw.all || !raw.filteringOptions.monitors.isEmpty || !raw.filteringOptions.workspaces.isEmpty
        }
        .filter("--all conflicts with \"filtering\" flags. Please use '--monitor all' instead of '--all' alias") { raw in
            raw.all.implies(raw.filteringOptions == ListWindowsCmdArgs.FilteringOptions())
        }
        .filter("--focused conflicts with other \"filtering\" flags") { raw in
            raw.filteringOptions.focused.implies(raw.filteringOptions.copy(\.focused, false) == ListWindowsCmdArgs.FilteringOptions())
        }
        .map { raw in
            raw.all ? raw.copy(\.filteringOptions.monitors, [.all]).copy(\.all, false) : raw // Normalize alias
        }
}

private func parseWorkspaces(input: SubArgParserInput) -> ParsedCliArgs<[WorkspaceFilter]> {
    let args = input.nonFlagArgs()
    let possibleValues = "\(workspace) possible values: (<workspace-name>|focused|visible)"
    if args.isEmpty {
        return .fail("\(workspaces) is mandatory. \(possibleValues)", advanceBy: args.count)
    }
    var workspaces: [WorkspaceFilter] = []
    var i = 0
    for workspaceRaw in args {
        switch workspaceRaw {
            case "visible": workspaces.append(.visible)
            case "focused": workspaces.append(.focused)
            default:
                switch WorkspaceName.parse(workspaceRaw) {
                    case .success(let unwrapped): workspaces.append(.name(unwrapped))
                    case .failure(let msg): return .fail(msg, advanceBy: i + 1)
                }
        }
        i += 1
    }
    return .succ(workspaces, advanceBy: workspaces.count)
}

public enum WorkspaceFilter: Equatable, Sendable {
    case focused
    case visible
    case name(WorkspaceName)
}
