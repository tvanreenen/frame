import Common
import Foundation

@MainActor
func runWorkspaceChangeHook(_ newWorkspace: String) {
    guard let executable = runtimeContext.config.workspaceChangeHook.first else { return }

    let process = Process()
    process.executableURL = URL(filePath: executable)
    process.arguments = Array(runtimeContext.config.workspaceChangeHook.dropFirst())
    process.environment = workspaceChangeHookEnvironment(newWorkspace: newWorkspace)
    _ = Result { try process.run() }
}

private func workspaceChangeHookEnvironment(newWorkspace: String) -> [String: String] {
    workspaceChangeHookEnvironment(newWorkspace: newWorkspace, baseEnv: ProcessInfo.processInfo.environment)
}

func workspaceChangeHookEnvironment(newWorkspace: String, baseEnv: [String: String]) -> [String: String] {
    var env = baseEnv
    env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:\(baseEnv["PATH"] ?? "")"
    env[FRAME_FOCUSED_WORKSPACE] = newWorkspace
    return env
}
