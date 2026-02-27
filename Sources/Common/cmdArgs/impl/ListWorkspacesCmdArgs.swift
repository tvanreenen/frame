import OrderedCollections

let onitor = "<monitor>"
let _monitors = "\(onitor)..."

public struct ListWorkspacesCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWorkspaces,
        help: list_workspaces_help_generated,
        flags: [
            // Filtering flags
            "--visible": boolFlag(\.filteringOptions.visible),
            "--empty": boolFlag(\.filteringOptions.empty),
            "--monitor": SubArgParser(\.filteringOptions.onMonitors, parseMonitorIds),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--count", "--json"],
        ],
    )

    public var filteringOptions = FilteringOptions()
    public var outputOnlyCount: Bool = false
    public var json: Bool = false

    public struct FilteringOptions: ConvenienceCopyable, Equatable, Sendable {
        public var onMonitors: [MonitorId] = []
        public var visible: Bool?
        public var empty: Bool?
    }
}

public func parseListWorkspacesCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListWorkspacesCmdArgs> {
    parseSpecificCmdArgs(ListWorkspacesCmdArgs(commonState: .init(args)), args)
        .filter("Mandatory option is not specified (--monitor)") { raw in
            !raw.filteringOptions.onMonitors.isEmpty
        }
}

func parseMonitorIds(input: SubArgParserInput) -> ParsedCliArgs<[MonitorId]> {
    let args = input.nonFlagArgs()
    let possibleValues = "\(onitor) possible values: (<monitor-id>|focused|mouse|all)"
    if args.isEmpty {
        return .fail("\(_monitors) is mandatory. \(possibleValues)", advanceBy: args.count)
    }
    var monitors: [MonitorId] = []
    var i = 0
    for monitor in args {
        switch Int.init(monitor) {
            case .some(let unwrapped):
                monitors.append(.index(unwrapped - 1))
            case _ where monitor == "mouse":
                monitors.append(.mouse)
            case _ where monitor == "all":
                monitors.append(.all)
            case _ where monitor == "focused":
                monitors.append(.focused)
            default:
                return .fail("Can't parse monitor ID '\(monitor)'. \(possibleValues)", advanceBy: i + 1)
        }
        i += 1
    }
    return .succ(monitors, advanceBy: monitors.count)
}

public enum MonitorId: Equatable, Sendable {
    case focused
    case all
    case mouse
    case index(Int)
}
