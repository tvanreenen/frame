import AppKit
import Common
import HotKey

func getDefaultConfigUrlFromProject() -> URL {
    var url = URL(filePath: #filePath)
    check(FileManager.default.fileExists(atPath: url.path))
    while !FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
        url.deleteLastPathComponent()
    }
    let projectRoot: URL = url
    return projectRoot.appending(component: "docs/config-examples/default-config.toml")
}

var defaultConfigUrl: URL {
    if isUnitTest {
        return getDefaultConfigUrlFromProject()
    } else {
        return Bundle.main.url(forResource: "default-config", withExtension: "toml")
            // Useful for debug builds that are not app bundles
            ?? getDefaultConfigUrlFromProject()
    }
}
@MainActor let defaultConfig: Config = {
    let parsedConfig = parseConfig(Result { try String(contentsOf: defaultConfigUrl, encoding: .utf8) }.getOrDie())
    if !parsedConfig.errors.isEmpty {
        die("Can't parse default config: \(parsedConfig.errors)")
    }
    return parsedConfig.config
}()

@MainActor
final class RuntimeContext {
    var config: Config
    var configUrl: URL
    var windowsById: [UInt32: Window]
    var appsByPid: [pid_t: MacApp]
    var appsWipByPid: [pid_t: AwaitableOneTimeBroadcastLatch]
    var appFocusJob: RunLoopJob?
    var closedWindowsCache: FrozenWorld

    init(config: Config, configUrl: URL) {
        self.config = config
        self.configUrl = configUrl
        windowsById = [:]
        appsByPid = [:]
        appsWipByPid = [:]
        appFocusJob = nil
        closedWindowsCache = FrozenWorld(workspaces: [], monitors: [], windowIds: [])
    }
}

@MainActor
let runtimeContext = RuntimeContext(config: defaultConfig, configUrl: defaultConfigUrl)

struct Config: ConvenienceCopyable {
    var startAtLogin: Bool = false
    var persistentWorkspaces: OrderedUniqueValues<String> = []
    var workspaceChangeHook: [String] = []
    var windowClassificationOverrides: [WindowClassificationOverride] = []
    var keyMapping = KeyMapping()

    var gaps: Gaps = .zero
    var workspaceToMonitorForceAssignment: [String: [MonitorDescription]] = [:]
    var bindings: [String: HotkeyBinding] = [:]
}
