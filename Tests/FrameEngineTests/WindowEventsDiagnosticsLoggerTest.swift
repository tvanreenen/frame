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
            aliveWindowIds: [2, 1],
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
        assertEquals((refresh["aliveWindowIds"] as? [NSNumber])?.map(\.intValue), [1, 2])
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

    private func parseLine(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
