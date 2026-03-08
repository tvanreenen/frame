import Common
import FrameEngine

struct DoctorCommand: Command {
    let args: DoctorCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    @MainActor
    func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        switch readConfig() {
            case .success(let (_, configUrl)):
                io.out("Config is valid: \(configUrl.path)")
                return true
            case .failure(let msg):
                io.err(msg)
                return false
        }
    }
}
