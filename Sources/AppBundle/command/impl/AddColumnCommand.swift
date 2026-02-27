import Common

struct AddColumnCommand: Command {
    let args: AddColumnCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let currentWindow = target.windowOrNil else { return io.err(noWindowIsFocused) }
        let workspace = target.workspace
        let currentColumn = currentWindow.column
        let newColumn = workspace.addColumn(after: currentColumn)
        currentWindow.bind(to: newColumn, adaptiveWeight: WEIGHT_AUTO, index: 0)
        return true
    }
}
