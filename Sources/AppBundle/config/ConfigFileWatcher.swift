import Common
import Foundation

private final class ConfigFileWatcher {
    private let source: DispatchSourceFileSystemObject
    private let fd: Int32

    init?(url: URL, onChange: @escaping @MainActor () -> Void) {
        fd = open(url.path, O_EVTONLY)
        if fd < 0 { return nil }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: .main,
        )
        source.setEventHandler { MainActor.checkIsolated { onChange() } }
        source.setCancelHandler { [fd] in close(fd) }
        source.activate()
    }

    deinit {
        source.cancel()
    }
}

@MainActor private var currentWatcher: ConfigFileWatcher? = nil
@MainActor private var debounceTask: Task<Void, any Error>? = nil

private let debounceDelay: Duration = .milliseconds(200)

@MainActor func syncConfigFileWatcher() {
    currentWatcher = nil
    if !runtimeContext.config.autoReloadConfig { return }
    currentWatcher = ConfigFileWatcher(url: runtimeContext.configUrl) {
        debounceTask?.cancel()
        debounceTask = Task {
            try await Task.sleep(for: debounceDelay)
            try await runLightSession(.configAutoReload) {
                _ = try await reloadConfig()
            }
        }
    }
}
