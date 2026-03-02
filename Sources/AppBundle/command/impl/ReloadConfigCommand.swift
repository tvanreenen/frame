import AppKit
import Common

struct ReloadConfigCommand: Command {
    let args: ReloadConfigCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        var stdout = ""
        let isOk = try await reloadConfig(stdout: &stdout)
        if !stdout.isEmpty {
            io.out(stdout)
        }
        return isOk
    }
}

@MainActor func reloadConfig(forceConfigUrl: URL? = nil) async throws -> Bool {
    var devNull = ""
    return try await reloadConfig(forceConfigUrl: forceConfigUrl, stdout: &devNull)
}

@MainActor func reloadConfig(
    forceConfigUrl: URL? = nil,
    stdout: inout String,
) async throws -> Bool {
    let result: Bool
    switch readConfig(forceConfigUrl: forceConfigUrl) {
        case .success(let (parsedConfig, url)):
            runtimeContext.config = parsedConfig
            runtimeContext.configUrl = url
            syncHotKeys()
            syncStartAtLogin()
            MessageModel.shared.message = nil
            result = true
        case .failure(let msg):
            stdout.append(msg)
            Task { @MainActor in
                MessageModel.shared.message = Message(
                    title: "Frame.app Configuration Error",
                    description: "Frame could not load your configuration file.",
                    body: msg,
                )
            }
            result = false
    }
    return result
}
