import Common
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
        let frameWindowId: String?
        let windowId: UInt32?
        let oldPlatformWindowId: UInt32?
        let newPlatformWindowId: UInt32?
        let notification: String?
        let source: String?
        let alreadyRegistered: Bool?
        let axWindowIds: [UInt32]?
        let authoritativeWindowIds: [UInt32]?
        let focusedWindowId: UInt32?
        let existingPlatformWindowIds: [UInt32]?
        let unmatchedFrameWindowIds: [String]?
        let unmatchedWindowIds: [UInt32]?
        let replacementFrameWindowId: String?
        let replacementReason: String?
        let applyResult: String?
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
                frameWindowId: nil,
                windowId: nil,
                oldPlatformWindowId: nil,
                newPlatformWindowId: nil,
                notification: notification,
                source: nil,
                alreadyRegistered: nil,
                axWindowIds: nil,
                authoritativeWindowIds: nil,
                focusedWindowId: nil,
                existingPlatformWindowIds: nil,
                unmatchedFrameWindowIds: nil,
                unmatchedWindowIds: nil,
                replacementFrameWindowId: nil,
                replacementReason: nil,
                applyResult: nil,
                placementKind: nil,
                title: nil,
            )
        }
    }

    package func logAppRefresh(
        bundleId: String?,
        pid: Int32,
        axWindowIds: [UInt32],
        authoritativeWindowIds: [UInt32],
        focusedWindowId: UInt32?,
    ) {
        queue.async {
            self.log(
                event: "app_refresh",
                bundleId: bundleId,
                pid: pid,
                frameWindowId: nil,
                windowId: nil,
                oldPlatformWindowId: nil,
                newPlatformWindowId: nil,
                notification: nil,
                source: nil,
                alreadyRegistered: nil,
                axWindowIds: axWindowIds.sorted(),
                authoritativeWindowIds: authoritativeWindowIds.sorted(),
                focusedWindowId: focusedWindowId,
                existingPlatformWindowIds: nil,
                unmatchedFrameWindowIds: nil,
                unmatchedWindowIds: nil,
                replacementFrameWindowId: nil,
                replacementReason: nil,
                applyResult: nil,
                placementKind: nil,
                title: nil,
            )
        }
    }

    package func logRefreshReconcile(
        bundleId: String?,
        pid: Int32,
        existingPlatformWindowIds: [UInt32],
        unmatchedFrameWindowIds: [String],
        unmatchedWindowIds: [UInt32],
        focusedWindowId: UInt32?,
        replacementFrameWindowId: FrameWindowId?,
        replacementWindowId: UInt32?,
        replacementReason: String,
        applyResult: String?,
    ) {
        queue.async {
            self.log(
                event: "refresh_reconcile",
                bundleId: bundleId,
                pid: pid,
                frameWindowId: nil,
                windowId: replacementWindowId,
                oldPlatformWindowId: nil,
                newPlatformWindowId: nil,
                notification: nil,
                source: nil,
                alreadyRegistered: nil,
                axWindowIds: nil,
                authoritativeWindowIds: nil,
                focusedWindowId: focusedWindowId,
                existingPlatformWindowIds: existingPlatformWindowIds.sorted(),
                unmatchedFrameWindowIds: unmatchedFrameWindowIds.sorted(),
                unmatchedWindowIds: unmatchedWindowIds.sorted(),
                replacementFrameWindowId: replacementFrameWindowId?.description,
                replacementReason: replacementReason,
                applyResult: applyResult,
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
                frameWindowId: nil,
                windowId: windowId,
                oldPlatformWindowId: nil,
                newPlatformWindowId: nil,
                notification: nil,
                source: source,
                alreadyRegistered: alreadyRegistered,
                axWindowIds: nil,
                authoritativeWindowIds: nil,
                focusedWindowId: nil,
                existingPlatformWindowIds: nil,
                unmatchedFrameWindowIds: nil,
                unmatchedWindowIds: nil,
                replacementFrameWindowId: nil,
                replacementReason: nil,
                applyResult: nil,
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
                frameWindowId: nil,
                windowId: windowId,
                oldPlatformWindowId: nil,
                newPlatformWindowId: nil,
                notification: nil,
                source: nil,
                alreadyRegistered: nil,
                axWindowIds: nil,
                authoritativeWindowIds: nil,
                focusedWindowId: nil,
                existingPlatformWindowIds: nil,
                unmatchedFrameWindowIds: nil,
                unmatchedWindowIds: nil,
                replacementFrameWindowId: nil,
                replacementReason: nil,
                applyResult: nil,
                placementKind: placementKind.rawValue,
                title: title,
            )
        }
    }

    package func logWindowRebound(
        bundleId: String?,
        pid: Int32,
        frameWindowId: FrameWindowId,
        oldPlatformWindowId: UInt32,
        newPlatformWindowId: UInt32,
    ) {
        queue.async {
            self.log(
                event: "window_rebound",
                bundleId: bundleId,
                pid: pid,
                frameWindowId: frameWindowId.description,
                windowId: nil,
                oldPlatformWindowId: oldPlatformWindowId,
                newPlatformWindowId: newPlatformWindowId,
                notification: nil,
                source: nil,
                alreadyRegistered: nil,
                axWindowIds: nil,
                authoritativeWindowIds: nil,
                focusedWindowId: nil,
                existingPlatformWindowIds: nil,
                unmatchedFrameWindowIds: nil,
                unmatchedWindowIds: nil,
                replacementFrameWindowId: nil,
                replacementReason: nil,
                applyResult: nil,
                placementKind: nil,
                title: nil,
            )
        }
    }

    package func logWindowGarbageCollected(bundleId: String?, pid: Int32, windowId: UInt32) {
        queue.async {
            self.log(
                event: "window_garbage_collected",
                bundleId: bundleId,
                pid: pid,
                frameWindowId: nil,
                windowId: windowId,
                oldPlatformWindowId: nil,
                newPlatformWindowId: nil,
                notification: nil,
                source: nil,
                alreadyRegistered: nil,
                axWindowIds: nil,
                authoritativeWindowIds: nil,
                focusedWindowId: nil,
                existingPlatformWindowIds: nil,
                unmatchedFrameWindowIds: nil,
                unmatchedWindowIds: nil,
                replacementFrameWindowId: nil,
                replacementReason: nil,
                applyResult: nil,
                placementKind: nil,
                title: nil,
            )
        }
    }

    private func log(
        event: String,
        bundleId: String?,
        pid: Int32?,
        frameWindowId: String?,
        windowId: UInt32?,
        oldPlatformWindowId: UInt32?,
        newPlatformWindowId: UInt32?,
        notification: String?,
        source: String?,
        alreadyRegistered: Bool?,
        axWindowIds: [UInt32]?,
        authoritativeWindowIds: [UInt32]?,
        focusedWindowId: UInt32?,
        existingPlatformWindowIds: [UInt32]?,
        unmatchedFrameWindowIds: [String]?,
        unmatchedWindowIds: [UInt32]?,
        replacementFrameWindowId: String?,
        replacementReason: String?,
        applyResult: String?,
        placementKind: String?,
        title: String?,
    ) {
        guard let bundleId, state.runtimeAppBundleId == bundleId else { return }

        let line = LogLine(
            timestamp: iso8601Formatter.string(from: .now),
            event: event,
            bundleId: bundleId,
            pid: pid,
            frameWindowId: frameWindowId,
            windowId: windowId,
            oldPlatformWindowId: oldPlatformWindowId,
            newPlatformWindowId: newPlatformWindowId,
            notification: notification,
            source: source,
            alreadyRegistered: alreadyRegistered,
            axWindowIds: axWindowIds,
            authoritativeWindowIds: authoritativeWindowIds,
            focusedWindowId: focusedWindowId,
            existingPlatformWindowIds: existingPlatformWindowIds,
            unmatchedFrameWindowIds: unmatchedFrameWindowIds,
            unmatchedWindowIds: unmatchedWindowIds,
            replacementFrameWindowId: replacementFrameWindowId,
            replacementReason: replacementReason,
            applyResult: applyResult,
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
