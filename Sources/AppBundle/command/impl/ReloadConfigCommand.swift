import AppKit
import Common

struct ReloadConfigCommand: Command {
    let args: ReloadConfigCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
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
            let parsedError = parseConfigErrorMessage(msg)
            Task { @MainActor in
                MessageModel.shared.message = Message(
                    title: appDisplayName,
                    description: parsedError.path.map {
                        "Failed to parse \($0). Frame will run with the built-in defaults until your configuration is fixed and reloaded."
                    } ?? "Failed to parse configuration. Frame will run with the built-in defaults until your configuration is fixed and reloaded.",
                    body: parsedError.errors,
                    steps: [
                        "Address the config errors below.",
                        "Run frame doctor.",
                        "Run frame reload-config (or quit and restart Frame).",
                    ],
                )
            }
            result = false
    }
    return result
}

private struct ParsedConfigErrorMessage {
    let path: String?
    let errors: String
}

private func parseConfigErrorMessage(_ raw: String) -> ParsedConfigErrorMessage {
    let withoutRecovery: String = if let recoveryStart = raw.range(of: "\n\nRecovery:\n") {
        String(raw[..<recoveryStart.lowerBound]).trim()
    } else {
        raw.trim()
    }

    let firstLine = withoutRecovery.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
    let prefix = "Failed to parse "
    if firstLine.hasPrefix(prefix) {
        let path = String(firstLine.dropFirst(prefix.count)).trim()
        let errors = withoutRecovery
            .split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
            .dropFirst()
            .joined(separator: "\n")
            .trim()
        return ParsedConfigErrorMessage(path: path.isEmpty ? nil : path, errors: errors)
    }
    return ParsedConfigErrorMessage(path: nil, errors: withoutRecovery)
}
