import Common

struct DoctorCommand: Command {
    let args: DoctorCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
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
