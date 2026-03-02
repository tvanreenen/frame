public struct WorkspaceCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .workspace,
        help: workspace_help_generated,
        flags: [
            "--wrap-around": optionalTrueBoolFlag(\._wrapAround),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),

            "--stdin": optionalTrueBoolFlag(\.explicitStdinFlag),
            "--no-stdin": optionalFalseBoolFlag(\.explicitStdinFlag),
        ],
        posArgs: [newArgParser(\.target, parseWorkspaceTarget, mandatoryArgPlaceholder: workspaceTargetPlaceholder)],
        conflictingOptions: [
            ["--stdin", "--no-stdin"],
        ],
    )

    public var target: Lateinit<WorkspaceTarget> = .uninitialized
    public var failIfNoop: Bool = false
    public var _wrapAround: Bool?
    public var explicitStdinFlag: Bool? = nil
}

public func parseWorkspaceCmdArgs(_ args: StrArrSlice) -> ParsedCmd<WorkspaceCmdArgs> {
    parseSpecificCmdArgs(WorkspaceCmdArgs(rawArgs: args), args)
        .filter("--wrap-around requires using \(NextPrev.unionLiteral) argument") { ($0._wrapAround != nil).implies($0.target.val.isRelative) }
        .filterNot("--fail-if-noop is incompatible with \(NextPrev.unionLiteral)") { $0.failIfNoop && $0.target.val.isRelative }
        .filter("--stdin and --no-stdin require using \(NextPrev.unionLiteral) argument") { ($0.explicitStdinFlag != nil).implies($0.target.val.isRelative) }
}

extension WorkspaceCmdArgs {
    public var wrapAround: Bool { _wrapAround ?? false }
    public var useStdin: Bool { explicitStdinFlag ?? false }
}

public enum WorkspaceTarget: Equatable, Sendable {
    case relative(NextPrev)
    case direct(WorkspaceName)

    var isDirect: Bool { !isRelative }
    public var isRelative: Bool {
        switch self {
            case .relative: true
            default: false
        }
    }

    public func workspaceNameOrNil() -> WorkspaceName? {
        switch self {
            case .direct(let name): name
            case .relative: nil
        }
    }
}

let workspaceTargetPlaceholder = "(<workspace-name>|next|prev)"

func parseWorkspaceTarget(i: ArgParserInput) -> ParsedCliArgs<WorkspaceTarget> {
    switch i.arg {
        case "next": .succ(.relative(.next), advanceBy: 1)
        case "prev": .succ(.relative(.prev), advanceBy: 1)
        default: .init(WorkspaceName.parse(i.arg).map(WorkspaceTarget.direct), advanceBy: 1)
    }
}
