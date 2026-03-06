import AppKit
import Common
import Foundation

@MainActor public func initAppBundle() {
    initAppBundle(session: currentSession)
}

@MainActor
func initAppBundle(session: AppSession) {
    Task { @MainActor in
        initTerminationHandler()
        isCli = false
        initServerArgs()
        if isDebug {
            interceptTermination(SIGINT)
            interceptTermination(SIGKILL)
        }
        if try await !reloadConfig() {
            var out = ""
            check(
                try await reloadConfig(forceConfigUrl: defaultConfigUrl, stdout: &out),
                """
                Can't load default config. Your installation is probably corrupted.
                Please don't modify '\(defaultConfigUrl)'

                \(out)
                """,
            )
        }

        await checkAccessibilityPermissions()
        startUnixSocketServer(session: session)
        GlobalObserver.initObserver(session: session)
        Workspace.garbageCollectUnusedWorkspaces() // init workspaces
        _ = Workspace.all.first?.focusWorkspace()
        try await session.runRefreshSessionBlocking(.startup, layoutWorkspaces: false)
    }
}

@TaskLocal
var _isStartup: Bool? = false
var isStartup: Bool { _isStartup ?? dieT("isStartup is not initialized") }

struct ServerArgs: Sendable {
    var configLocation: String? = nil
}

private let serverHelp = """
    USAGE: \(CommandLine.arguments.first ?? "\(cliName).app/Contents/MacOS/FrameApp") [<options>]

    OPTIONS:
      -h, --help              Print help
      -v, --version           Print \(productName) version
      --config-path <path>    Config path. It will take priority over ~/\(configDotfileName)
                              and ${XDG_CONFIG_HOME}/\(configDirName)/\(configDotfileName.removePrefix("."))
    """

nonisolated(unsafe) private var _serverArgs = ServerArgs()
var serverArgs: ServerArgs { _serverArgs }
private func initServerArgs() {
    let args = CommandLine.arguments.slice(1...) ?? []
    if args.contains(where: { $0 == "-h" || $0 == "--help" }) {
        print(serverHelp)
        exit(0)
    }
    var index = 0
    while index < args.count {
        let current = args[index]
        index += 1
        switch current {
            case "--version", "-v":
                print(appVersionForDisplay)
                exit(0)
            case "--config-path":
                if let arg = args.getOrNil(atIndex: index) {
                    _serverArgs.configLocation = arg
                } else {
                    exit(stderrMsg: "Missing <path> in --config-path flag")
                }
                index += 1
            case "-NSDocumentRevisionsDebugMode" where isDebug:
                // Skip Xcode CLI args.
                // Usually it's '-NSDocumentRevisionsDebugMode NO'/'-NSDocumentRevisionsDebugMode YES'
                while args.getOrNil(atIndex: index)?.starts(with: "-") == false { index += 1 }
            default:
                exit(stderrMsg: "Unrecognized flag '\(args.first.orDie())'")
        }
    }
    if let path = serverArgs.configLocation, !FileManager.default.fileExists(atPath: path) {
        exit(stderrMsg: "\(path) doesn't exist")
    }
}
