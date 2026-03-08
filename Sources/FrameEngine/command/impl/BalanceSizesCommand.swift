import Common
import Foundation

struct BalanceSizesCommand: Command {
    let args: BalanceSizesCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        balance(target.workspace.columnsRoot)
        return true
    }
}

@MainActor
private func balance(_ parent: Column) {
    for child in parent.children {
        child.setWeight(parent.orientation, 1)
        if let child = child as? Column {
            balance(child)
        }
    }
}
