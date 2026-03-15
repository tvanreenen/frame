import Foundation

package let defaultWindowEventsDiagnosticsLogPath = "/tmp/frame-window-events.log"

package final class WindowEventsDiagnosticsLogger: @unchecked Sendable {
    private struct State: Equatable {
        var runtimeAppBundleId: String? = nil
    }

    package enum RuntimeToggleResult: Equatable {
        case enabled(bundleId: String, logPath: String)
        case disabled(previousBundleId: String, logPath: String)
        case missingFrontmostApp
    }

    private struct LogLine: Encodable {
        let timestamp: String
        let event: String
        let bundleId: String
        let pid: Int32?
        let windowId: UInt32?
        let notification: String?
        let source: String?
        let alreadyRegistered: Bool?
        let aliveWindowIds: [UInt32]?
        let focusedWindowId: UInt32?
        let placementKind: String?
        let title: String?
    }

    private var state = State()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private let iso8601Formatter = ISO8601DateFormatter()
    private let queue = DispatchQueue(label: "frame.window-events-diagnostics")
    private let logPath: String

    package init(logPath: String = defaultWindowEventsDiagnosticsLogPath) {
        self.logPath = logPath
    }

    package func isEnabled(forBundleId bundleId: String?) -> Bool {
        guard let bundleId else { return false }
        return queue.sync { state.runtimeAppBundleId == bundleId }
    }

    package func flush() {
        queue.sync {}
    }

    package func toggleRuntime(forBundleId bundleId: String?) -> RuntimeToggleResult {
        queue.sync {
            if let activeBundleId = state.runtimeAppBundleId {
                state.runtimeAppBundleId = nil
                return .disabled(previousBundleId: activeBundleId, logPath: logPath)
            }
            guard let bundleId else { return .missingFrontmostApp }
            state.runtimeAppBundleId = bundleId
            truncateLogFile()
            return .enabled(bundleId: bundleId, logPath: logPath)
        }
    }

    package func logAxNotification(notification: String, bundleId: String?, pid: Int32?) {
        queue.async {
            self.log(
                event: "ax_notification",
                bundleId: bundleId,
                pid: pid,
                windowId: nil,
                notification: notification,
                source: nil,
                alreadyRegistered: nil,
                aliveWindowIds: nil,
                focusedWindowId: nil,
                placementKind: nil,
                title: nil,
            )
        }
    }

    package func logAppRefresh(bundleId: String?, pid: Int32, aliveWindowIds: [UInt32], focusedWindowId: UInt32?) {
        queue.async {
            self.log(
                event: "app_refresh",
                bundleId: bundleId,
                pid: pid,
                windowId: nil,
                notification: nil,
                source: nil,
                alreadyRegistered: nil,
                aliveWindowIds: aliveWindowIds.sorted(),
                focusedWindowId: focusedWindowId,
                placementKind: nil,
                title: nil,
            )
        }
    }

    package func logAxWindowSeen(
        bundleId: String?,
        pid: Int32,
        windowId: UInt32,
        source: String,
        alreadyRegistered: Bool,
    ) {
        queue.async {
            self.log(
                event: "ax_window_seen",
                bundleId: bundleId,
                pid: pid,
                windowId: windowId,
                notification: nil,
                source: source,
                alreadyRegistered: alreadyRegistered,
                aliveWindowIds: nil,
                focusedWindowId: nil,
                placementKind: nil,
                title: nil,
            )
        }
    }

    package func logWindowRegistered(
        bundleId: String?,
        pid: Int32,
        windowId: UInt32,
        placementKind: WindowPlacementKind,
        title: String?,
    ) {
        queue.async {
            self.log(
                event: "window_registered",
                bundleId: bundleId,
                pid: pid,
                windowId: windowId,
                notification: nil,
                source: nil,
                alreadyRegistered: nil,
                aliveWindowIds: nil,
                focusedWindowId: nil,
                placementKind: placementKind.rawValue,
                title: title,
            )
        }
    }

    package func logWindowGarbageCollected(bundleId: String?, pid: Int32, windowId: UInt32) {
        queue.async {
            self.log(
                event: "window_garbage_collected",
                bundleId: bundleId,
                pid: pid,
                windowId: windowId,
                notification: nil,
                source: nil,
                alreadyRegistered: nil,
                aliveWindowIds: nil,
                focusedWindowId: nil,
                placementKind: nil,
                title: nil,
            )
        }
    }

    private func log(
        event: String,
        bundleId: String?,
        pid: Int32?,
        windowId: UInt32?,
        notification: String?,
        source: String?,
        alreadyRegistered: Bool?,
        aliveWindowIds: [UInt32]?,
        focusedWindowId: UInt32?,
        placementKind: String?,
        title: String?,
    ) {
        guard let bundleId, state.runtimeAppBundleId == bundleId else { return }

        let line = LogLine(
            timestamp: iso8601Formatter.string(from: .now),
            event: event,
            bundleId: bundleId,
            pid: pid,
            windowId: windowId,
            notification: notification,
            source: source,
            alreadyRegistered: alreadyRegistered,
            aliveWindowIds: aliveWindowIds,
            focusedWindowId: focusedWindowId,
            placementKind: placementKind,
            title: title,
        )

        guard let data = try? encoder.encode(line) else { return }
        appendLine(data)
    }

    private func truncateLogFile() {
        let url = URL(filePath: logPath)
        let directoryUrl = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true, attributes: nil)
        _ = FileManager.default.createFile(atPath: url.path, contents: Data())
    }

    private func appendLine(_ data: Data) {
        let url = URL(filePath: logPath)
        let directoryUrl = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true, attributes: nil)
        if !FileManager.default.fileExists(atPath: url.path) {
            _ = FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data + Data([0x0A]))
    }
}
