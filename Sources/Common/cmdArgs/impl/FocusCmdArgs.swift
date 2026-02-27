public struct FocusCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .focus,
        help: focus_help_generated,
        flags: [
            "--ignore-floating": falseBoolFlag(\.floatingAsTiling),
            "--window-id": SubArgParser(\.windowId, upcastSubArgParserFun(parseUInt32SubArg)),

            "--boundaries": SubArgParser(\.rawBoundaries, upcastSubArgParserFun(parseBoundaries)),
            "--boundaries-action": SubArgParser(\.rawBoundariesAction, upcastSubArgParserFun(parseBoundariesAction)),
            "--wrap-around": trueBoolFlag(\.wrapAroundAlias),
        ],
        posArgs: [ArgParser(\.direction, upcastArgParserFun(parseCardinalDirectionArg))],
        conflictingOptions: [
            ["--wrap-around", "--boundaries-action"],
            ["--wrap-around", "--boundaries"],
        ],
    )

    public var rawBoundaries: Boundaries? = nil // todo cover boundaries wrapping with tests
    public var rawBoundariesAction: WhenBoundariesCrossed? = nil
    fileprivate var wrapAroundAlias: Bool = false
    public var direction: CardinalDirection? = nil
    public var floatingAsTiling: Bool = true

    public init(rawArgs: StrArrSlice, direction: CardinalDirection) {
        self.commonState = .init(rawArgs)
        self.direction = direction
    }

    public init(rawArgs: StrArrSlice, windowId: UInt32) {
        self.commonState = .init(rawArgs)
        self.windowId = windowId
    }

    public enum Boundaries: String, CaseIterable, Equatable, Sendable {
        case workspace
        case allMonitorsOuterFrame = "all-monitors-outer-frame"
    }
    public enum WhenBoundariesCrossed: String, CaseIterable, Equatable, Sendable {
        case stop = "stop"
        case fail = "fail"
        case wrapAroundTheWorkspace = "wrap-around-the-workspace"
        case wrapAroundAllMonitors = "wrap-around-all-monitors"
    }
}

public enum FocusCmdTarget {
    case direction(CardinalDirection)
    case windowId(UInt32)
}

extension FocusCmdArgs {
    public var target: FocusCmdTarget {
        if let direction {
            return .direction(direction)
        }
        if let windowId {
            return .windowId(windowId)
        }
        die("Parser invariants are broken")
    }

    public var boundaries: Boundaries { rawBoundaries ?? .workspace }
    public var boundariesAction: WhenBoundariesCrossed {
        wrapAroundAlias ? .wrapAroundTheWorkspace : (rawBoundariesAction ?? .stop)
    }
}

public func parseFocusCmdArgs(_ args: StrArrSlice) -> ParsedCmd<FocusCmdArgs> {
    return parseSpecificCmdArgs(FocusCmdArgs(rawArgs: args), args)
        .flatMap { (raw: FocusCmdArgs) -> ParsedCmd<FocusCmdArgs> in
            raw.boundaries == .workspace && raw.boundariesAction == .wrapAroundAllMonitors
                ? .failure("\(raw.boundaries.rawValue) and \(raw.boundariesAction.rawValue) is an invalid combination of values")
                : .cmd(raw)
        }
        .filter("Mandatory argument is missing. \(CardinalDirection.unionLiteral), --window-id is required") {
            $0.direction != nil || $0.windowId != nil
        }
        .filter("--window-id is incompatible with other options") {
            $0.windowId == nil || $0 == FocusCmdArgs(rawArgs: args, windowId: $0.windowId.orDie())
        }
}

private func parseBoundariesAction(i: SubArgParserInput) -> ParsedCliArgs<FocusCmdArgs.WhenBoundariesCrossed> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(parseEnum(arg, FocusCmdArgs.WhenBoundariesCrossed.self), advanceBy: 1)
    } else {
        return .fail("<action> is mandatory", advanceBy: 0)
    }
}

private func parseBoundaries(i: SubArgParserInput) -> ParsedCliArgs<FocusCmdArgs.Boundaries> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(parseEnum(arg, FocusCmdArgs.Boundaries.self), advanceBy: 1)
    } else {
        return .fail("<boundary> is mandatory", advanceBy: 0)
    }
}
