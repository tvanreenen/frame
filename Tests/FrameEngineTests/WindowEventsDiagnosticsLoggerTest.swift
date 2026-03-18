@testable import FrameEngine
import FrameTestSupport
import Foundation
import XCTest

final class WindowEventsDiagnosticsLoggerTest: XCTestCase {
    func testToggleRuntimeTruncatesOnceAndMatchingBundleWritesLog() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "frame-window-events-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        try "stale\n".write(to: url, atomically: true, encoding: .utf8)
        let logger = WindowEventsDiagnosticsLogger(logPath: url.path)
        let enable = logger.toggleRuntime(forBundleId: "com.mitchellh.ghostty")

        assertEquals(enable, .enabled(bundleId: "com.mitchellh.ghostty", logPath: url.path))
        assertEquals(try String(contentsOf: url, encoding: .utf8), "")

        logger.logAppRefresh(
            bundleId: "com.mitchellh.ghostty",
            pid: 42,
            axWindowIds: [2, 1],
            authoritativeWindowIds: [2],
            focusedWindowId: 2,
        )
        logger.logWindowGarbageCollected(
            bundleId: "com.mitchellh.ghostty",
            pid: 42,
            windowId: 2,
        )

        logger.flush()

        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        assertEquals(lines.count, 2)

        let refresh = try XCTUnwrap(parseLine(lines[0]))
        assertEquals(refresh["event"] as? String, "app_refresh")
        assertEquals(refresh["bundleId"] as? String, "com.mitchellh.ghostty")
        assertEquals(refresh["placementKind"] as? String, nil)
        assertEquals((refresh["axWindowIds"] as? [NSNumber])?.map(\.intValue), [1, 2])
        assertEquals((refresh["authoritativeWindowIds"] as? [NSNumber])?.map(\.intValue), [2])
        assertEquals((refresh["focusedWindowId"] as? NSNumber)?.intValue, 2)

        let gc = try XCTUnwrap(parseLine(lines[1]))
        assertEquals(gc["event"] as? String, "window_garbage_collected")
        assertEquals((gc["windowId"] as? NSNumber)?.intValue, 2)
    }

    func testNonMatchingBundleDoesNotWrite() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "frame-window-events-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let logger = WindowEventsDiagnosticsLogger(logPath: url.path)
        _ = logger.toggleRuntime(forBundleId: "com.mitchellh.ghostty")
        logger.logWindowRegistered(
            bundleId: "com.pixelmatorteam.pixelmator.x",
            pid: 91,
            windowId: 100,
            placementKind: .tiling,
            title: "Ignored",
        )

        logger.flush()

        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        assertEquals(contents, "")
    }

    func testWindowRegisteredIncludesPlacementKind() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "frame-window-events-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let logger = WindowEventsDiagnosticsLogger(logPath: url.path)
        _ = logger.toggleRuntime(forBundleId: "com.mitchellh.ghostty")
        logger.logWindowRegistered(
            bundleId: "com.mitchellh.ghostty",
            pid: 7,
            windowId: 55,
            placementKind: .excluded,
            title: "Popup",
        )

        logger.flush()

        let line = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = try XCTUnwrap(parseLine(line))
        assertEquals(payload["event"] as? String, "window_registered")
        assertEquals(payload["placementKind"] as? String, "excluded")
        assertEquals(payload["title"] as? String, "Popup")
    }

    func testSecondToggleStopsLogging() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "frame-window-events-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let logger = WindowEventsDiagnosticsLogger(logPath: url.path)

        let enable = logger.toggleRuntime(forBundleId: "com.mitchellh.ghostty")
        assertEquals(enable, .enabled(bundleId: "com.mitchellh.ghostty", logPath: url.path))

        logger.logWindowGarbageCollected(bundleId: "com.mitchellh.ghostty", pid: 1, windowId: 10)

        let disable = logger.toggleRuntime(forBundleId: "com.apple.Terminal")
        assertEquals(disable, .disabled(previousBundleId: "com.mitchellh.ghostty", logPath: url.path))

        logger.logWindowGarbageCollected(bundleId: "com.mitchellh.ghostty", pid: 3, windowId: 30)
        logger.flush()

        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        assertEquals(lines.count, 1)

        let payload = try XCTUnwrap(parseLine(lines[0]))
        assertEquals(payload["bundleId"] as? String, "com.mitchellh.ghostty")
        assertEquals((payload["windowId"] as? NSNumber)?.intValue, 10)
    }

    func testPlatformRefreshLogsObservedAndUnavailableStates() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "frame-window-events-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let logger = WindowEventsDiagnosticsLogger(logPath: url.path)
        _ = logger.toggleRuntime(forBundleId: "com.mitchellh.ghostty")
        logger.logPlatformRefreshObserved()
        logger.logPlatformRefreshUnavailable(reason: .screenLocked)

        logger.flush()

        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        assertEquals(lines.count, 2)

        let observed = try XCTUnwrap(parseLine(lines[0]))
        assertEquals(observed["event"] as? String, "platform_refresh")
        assertEquals(observed["platformRefreshState"] as? String, "observed")
        XCTAssertNil(observed["unavailableReason"])

        let unavailable = try XCTUnwrap(parseLine(lines[1]))
        assertEquals(unavailable["event"] as? String, "platform_refresh")
        assertEquals(unavailable["platformRefreshState"] as? String, "unavailable")
        assertEquals(unavailable["unavailableReason"] as? String, "screenLocked")
    }

    func testWindowReboundIncludesLogicalAndPlatformIds() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "frame-window-events-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let logger = WindowEventsDiagnosticsLogger(logPath: url.path)
        _ = logger.toggleRuntime(forBundleId: "com.mitchellh.ghostty")
        logger.logWindowRebound(
            bundleId: "com.mitchellh.ghostty",
            pid: 7,
            frameWindowId: 17,
            oldPlatformWindowId: 55,
            newPlatformWindowId: 56,
        )

        logger.flush()

        let line = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = try XCTUnwrap(parseLine(line))
        assertEquals(payload["event"] as? String, "window_rebound")
        assertEquals(payload["frameWindowId"] as? String, "frame-17")
        assertEquals((payload["oldPlatformWindowId"] as? NSNumber)?.intValue, 55)
        assertEquals((payload["newPlatformWindowId"] as? NSNumber)?.intValue, 56)
    }

    @MainActor
    func testRefreshReconcileIncludesUnmatchedSetsAndDecision() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "frame-window-events-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 17, parent: workspace.columnsRoot)
        let logger = WindowEventsDiagnosticsLogger(logPath: url.path)
        _ = logger.toggleRuntime(forBundleId: "com.frame.test-app")
        logger.logRefreshReconcile(
            bundleId: "com.frame.test-app",
            pid: 7,
            existingPlatformWindowIds: [17, 99],
            unmatchedFrameWindowIds: [window.windowId.description],
            unmatchedWindowIds: [55],
            focusedWindowId: 55,
            replacementFrameWindowId: window.windowId,
            replacementWindowId: 55,
            replacementReason: "rebind",
            applyResult: nil,
        )

        logger.flush()

        let line = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = try XCTUnwrap(parseLine(line))
        assertEquals(payload["event"] as? String, "refresh_reconcile")
        assertEquals((payload["existingPlatformWindowIds"] as? [NSNumber])?.map(\.intValue), [17, 99])
        assertEquals(payload["unmatchedFrameWindowIds"] as? [String], [window.windowId.description])
        assertEquals((payload["unmatchedWindowIds"] as? [NSNumber])?.map(\.intValue), [55])
        assertEquals(payload["replacementFrameWindowId"] as? String, window.windowId.description)
        assertEquals((payload["windowId"] as? NSNumber)?.intValue, 55)
        assertEquals(payload["replacementReason"] as? String, "rebind")
        XCTAssertNil(payload["applyResult"])
    }

    private func parseLine(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
