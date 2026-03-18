import Common

struct RemoveColumnCommand: Command {
    let args: RemoveColumnCmdArgs

    func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let workspace = target.workspace
        guard let lastColumn = workspace.columns.last else { return true }
        workspace.removeColumn(lastColumn)
        return true
    }
}
