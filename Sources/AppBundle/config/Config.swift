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
var currentSession = AppSession(config: defaultConfig, configUrl: defaultConfigUrl)
@MainActor var runtimeContext: AppSession { currentSession }

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
