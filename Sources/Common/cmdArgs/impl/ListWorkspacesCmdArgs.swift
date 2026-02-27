import OrderedCollections

private let monitorPlaceholder = "<monitor>"
private let monitorListPlaceholder = "\(monitorPlaceholder)..."

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
    let possibleValues = "\(monitorPlaceholder) possible values: (<monitor-id>|focused|mouse|all)"
    if args.isEmpty {
        return .fail("\(monitorListPlaceholder) is mandatory. \(possibleValues)", advanceBy: args.count)
    }
    var monitors: [MonitorId] = []
    var i = 0
    for rawMonitor in args {
        switch Int.init(rawMonitor) {
            case .some(let index1Based) where index1Based > 0:
                monitors.append(.index(index1Based - 1))
            case .some:
                return .fail("Can't parse monitor ID '\(rawMonitor)'. \(possibleValues)", advanceBy: i + 1)
            case _ where rawMonitor == "mouse":
                monitors.append(.mouse)
            case _ where rawMonitor == "all":
                monitors.append(.all)
            case _ where rawMonitor == "focused":
                monitors.append(.focused)
            default:
                return .fail("Can't parse monitor ID '\(rawMonitor)'. \(possibleValues)", advanceBy: i + 1)
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
