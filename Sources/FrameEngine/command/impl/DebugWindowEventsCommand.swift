import Common

struct DebugWindowEventsCommand: Command {
    let args: DebugWindowEventsCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    @MainActor
    func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) -> Bool {
        let result = session.windowEventsDiagnosticsLogger
            .toggleRuntime(forBundleId: session.platformServices.frontmostAppBundleId())

        switch result {
            case .enabled(let bundleId, let logPath):
                return io.out("Window diagnostics: ON for \(bundleId) (\(logPath))")
            case .disabled(let previousBundleId, let logPath):
                return io.out(previousBundleId.isEmpty
                    ? "Window diagnostics: OFF"
                    : "Window diagnostics: OFF for \(previousBundleId) (\(logPath))")
            case .missingFrontmostApp:
                return io.err("No frontmost app bundle id available")
        }
    }
}
