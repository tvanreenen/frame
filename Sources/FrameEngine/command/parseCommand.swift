import Common

package func parseCommand(_ raw: String) -> ParsedCmd<any Command> {
    return switch raw.splitArgs() {
        case .success(let args): parseCommand(args)
        case .failure(let fail): .failure(fail)
    }
}

package func parseCommand(_ args: [String]) -> ParsedCmd<any Command> {
    parseCmdArgs(args.slice).map { $0.toCommand() }
}
