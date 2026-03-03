public struct DoctorCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .doctor,
        help: doctor_help_generated,
        flags: [:],
        posArgs: [],
    )
}
