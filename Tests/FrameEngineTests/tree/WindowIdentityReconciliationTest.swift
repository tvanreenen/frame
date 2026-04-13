@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import XCTest
import FrameTestSupport

@MainActor
final class WindowIdentityReconciliationTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testRefreshRebindsSingleLogicalWindowAcrossPlatformIdChurn() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let original = TestWindow.new(
            id: 3193,
            parent: column,
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )
        TestApp.shared.setWindowRect(
            windowId: 3244,
            Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )

        currentSession.platformServices.refreshPlatformState = {
            .observed(appSnapshots: [(TestApp.shared as any WindowPlatformApp, PlatformAppRefreshSnapshot(windowIds: [3244], focusedWindowId: 3244))])
        }

        try await currentSession.runRefreshSessionBlocking(.menuBarButton, layoutWorkspaces: false)

        XCTAssertTrue(Window.get(byId: original.windowId) === original)
        XCTAssertTrue(Window.get(byPlatformWindowId: 3244) === original)
        XCTAssertNil(Window.get(byPlatformWindowId: 3193))
        assertEquals(original.platformWindowId, 3244)
        assertEquals(workspace.allLeafWindowsRecursive.count, 1)
    }

    func testMakeAppRefreshPlanUsesFrozenBindingsForSingleWindowChurn() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let original = TestWindow.new(
            id: 4044,
            parent: column,
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )
        let bindingSnapshots = [
            AppWindowBindingSnapshot(
                frameWindowId: original.windowId,
                platformWindowId: 4044,
                appPid: TestApp.shared.pid,
            ),
        ]

        let plan = try await currentSession.makeAppRefreshPlan(
            app: TestApp.shared,
            snapshot: PlatformAppRefreshSnapshot(windowIds: [4348], focusedWindowId: 4348),
            bindingSnapshots: bindingSnapshots,
        )

        assertEquals(plan.snapshotPlatformWindowIds, [4044])
        assertEquals(plan.unmatchedFrameWindowIds, [original.windowId])
        assertEquals(plan.unmatchedWindowIds, [4348])
        assertEquals(plan.replacementFrameWindowId, original.windowId)
        assertEquals(plan.replacementWindowId, 4348)
        assertEquals(plan.replacementReason, "rebind")
        assertEquals(plan.rebind?.expectedPlatformWindowId, 4044)
        assertEquals(plan.rebind?.newPlatformWindowId, 4348)
        assertEquals(plan.garbageCollections, [])
        assertEquals(plan.registerWindowIds, [])
    }

    func testRefreshRebindsExistingWindowAndRegistersSurplusWindow() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let original = TestWindow.new(
            id: 3193,
            parent: column,
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )
        _ = original.focusWindow()

        TestApp.shared.setWindowRect(
            windowId: 3244,
            Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )
        TestApp.shared.setWindowRect(
            windowId: 3356,
            Rect(topLeftX: 900, topLeftY: 0, width: 800, height: 600),
        )

        currentSession.platformServices.refreshPlatformState = {
            .observed(appSnapshots: [(TestApp.shared as any WindowPlatformApp, PlatformAppRefreshSnapshot(windowIds: [3244, 3356], focusedWindowId: 3356))])
        }

        try await currentSession.runRefreshSessionBlocking(.menuBarButton, layoutWorkspaces: false)

        let secondWindow = Window.get(byPlatformWindowId: 3356)

        XCTAssertTrue(Window.get(byPlatformWindowId: 3244) === original)
        XCTAssertNotNil(secondWindow)
        XCTAssertFalse(secondWindow === original)
        assertEquals(original.platformWindowId, 3244)
        assertEquals(workspace.allLeafWindowsRecursive.count, 2)
    }

    func testRefreshRecoversNativeFocusAfterRebindInSameCycle() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let original = TestWindow.new(
            id: 3193,
            parent: column,
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )
        _ = workspace.focusWorkspace()

        TestApp.shared.setWindowRect(
            windowId: 3244,
            Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )
        currentSession.platformServices.nativeFocusedWindow = {
            NativeFocusedWindowSnapshot(app: TestApp.shared, platformWindowId: 3244)
        }
        currentSession.platformServices.refreshPlatformState = {
            .observed(appSnapshots: [(TestApp.shared as any WindowPlatformApp, PlatformAppRefreshSnapshot(windowIds: [3244], focusedWindowId: 3244))])
        }

        try await currentSession.runRefreshSessionBlocking(.menuBarButton, layoutWorkspaces: false)

        XCTAssertTrue(Window.get(byId: original.windowId) === original)
        XCTAssertTrue(focus.windowOrNil === original)
        assertEquals(Window.allWindows.count, 1)
        assertEquals(original.platformWindowId, 3244)
    }

    func testUnavailablePlatformRefreshPreservesLogicalWindows() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let original = TestWindow.new(
            id: 4044,
            parent: column,
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )

        currentSession.platformServices.refreshPlatformState = {
            .unavailable(reason: .screenLocked)
        }

        try await currentSession.runRefreshSessionBlocking(.menuBarButton, layoutWorkspaces: false)

        XCTAssertTrue(Window.get(byId: original.windowId) === original)
        XCTAssertTrue(original.nodeWorkspace === workspace)
        assertEquals(Window.allWindows.count, 1)
    }

    func testObservedRefreshAfterOutagePreservesLogicalWindow() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let original = TestWindow.new(
            id: 4044,
            parent: column,
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )
        var refreshCount = 0

        currentSession.platformServices.refreshPlatformState = {
            defer { refreshCount += 1 }
            if refreshCount == 0 {
                return .unavailable(reason: .screenLocked)
            }
            return .observed(appSnapshots: [(TestApp.shared as any WindowPlatformApp, PlatformAppRefreshSnapshot(windowIds: [4044], focusedWindowId: 4044))])
        }

        try await currentSession.runRefreshSessionBlocking(.menuBarButton, layoutWorkspaces: false)

        try await currentSession.runRefreshSessionBlocking(.menuBarButton, layoutWorkspaces: false)

        XCTAssertTrue(Window.get(byId: original.windowId) === original)
        XCTAssertTrue(Window.get(byPlatformWindowId: 4044) === original)
        XCTAssertTrue(original.nodeWorkspace === workspace)
        assertEquals(Window.allWindows.count, 1)
    }

    func testRebindLogsWindowReboundWithoutWindowRegistered() throws {
        let logUrl = FileManager.default.temporaryDirectory.appending(path: "frame-window-events-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: logUrl) }

        currentSession = AppSession(
            config: defaultConfig,
            configUrl: defaultConfigUrl,
            windowEventsDiagnosticsLogger: WindowEventsDiagnosticsLogger(logPath: logUrl.path),
        )
        runtimeContext.config.bindings = [:]
        runtimeContext.config.persistentWorkspaces = []
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let original = TestWindow.new(
            id: 3193,
            parent: column,
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )

        let enable = currentSession.windowEventsDiagnosticsLogger.toggleRuntime(forBundleId: TestApp.shared.rawAppBundleId)
        assertEquals(enable, .enabled(bundleId: "com.frame.test-app", logPath: logUrl.path))

        original.rebind(
            toPlatformWindowId: 3244,
            lastKnownSize: CGSize(width: 800, height: 600),
        )
        currentSession.windowEventsDiagnosticsLogger.flush()

        let lines = try String(contentsOf: logUrl, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        assertEquals(lines.count, 1)

        let payload = try XCTUnwrap(parseLine(lines[0]))
        assertEquals(payload["event"] as? String, "window_rebound")
        assertEquals(payload["frameWindowId"] as? String, original.windowId.description)
        assertEquals((payload["oldPlatformWindowId"] as? NSNumber)?.intValue, 3193)
        assertEquals((payload["newPlatformWindowId"] as? NSNumber)?.intValue, 3244)
        XCTAssertNil(payload["windowId"])
    }

    func testApplyAppRefreshPlanSkipsWhenSnapshotDrifts() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let original = TestWindow.new(
            id: 4044,
            parent: column,
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 800, height: 600),
        )
        let bindingSnapshots = [
            AppWindowBindingSnapshot(
                frameWindowId: original.windowId,
                platformWindowId: 4044,
                appPid: TestApp.shared.pid,
            ),
        ]

        let plan = try await currentSession.makeAppRefreshPlan(
            app: TestApp.shared,
            snapshot: PlatformAppRefreshSnapshot(windowIds: [4348], focusedWindowId: 4348),
            bindingSnapshots: bindingSnapshots,
        )

        original.rebind(
            toPlatformWindowId: 5000,
            lastKnownSize: CGSize(width: 800, height: 600),
        )

        try await currentSession.applyAppRefreshPlan(plan, app: TestApp.shared)

        XCTAssertTrue(Window.get(byId: original.windowId) === original)
        assertEquals(original.platformWindowId, 5000)
        XCTAssertNil(Window.get(byPlatformWindowId: 4348))
        assertEquals(Window.allWindows.count, 1)
    }

    private func parseLine(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
