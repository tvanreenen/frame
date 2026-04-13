@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import Foundation
import XCTest
import FrameTestSupport

private struct RegistrationTestMonitor: Monitor {
    let systemMonitorIndex: Int
    let name: String
    let rect: Rect
    let visibleRect: Rect
    let isMain: Bool

    var height: CGFloat { rect.height }
    var width: CGFloat { rect.width }
}

@MainActor
final class WindowRegistrationTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testWindowRegistrationUsesFocusedColumnForNewTilingPlacement() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 785, parent: col1)
        _ = TestWindow.new(id: 786, parent: col2).focusWindow()

        let window = try await Window.getOrRegister(windowId: 787, app: TestApp.shared)
        let unwrappedWindow = try XCTUnwrap(window)

        XCTAssertTrue(unwrappedWindow.parent === col2)
    }

    func testWindowRegistrationPrefersRectDerivedWorkspaceOverFocusedWorkspaceFallback() async throws {
        let previousPlatformServices = currentSession.platformServices
        defer { currentSession.platformServices = previousPlatformServices }

        let mainMonitor = RegistrationTestMonitor(
            systemMonitorIndex: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        let secondaryMonitor = RegistrationTestMonitor(
            systemMonitorIndex: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        currentSession.platformServices = PlatformServices(
            mainMonitor: { mainMonitor },
            monitors: { [mainMonitor, secondaryMonitor] },
        )

        let mainWorkspace = Workspace.get(byName: "main-workspace")
        let focusedWorkspace = Workspace.get(byName: "focused-workspace")
        check(currentSession.setActiveWorkspace(mainWorkspace, on: mainMonitor.rect.topLeftCorner))
        check(currentSession.setActiveWorkspace(focusedWorkspace, on: secondaryMonitor.rect.topLeftCorner))
        check(focusedWorkspace.focusWorkspace())

        let rect = Rect(topLeftX: 120, topLeftY: 90, width: 640, height: 480)
        TestApp.shared.setWindowRegistrationSnapshot(
            windowId: 788,
            WindowRegistrationSnapshot(
                rect: rect,
                placementDecision: WindowPlacementDecision(
                    placementKind: .tiling,
                    reason: "test_snapshot",
                ),
            ),
        )

        let window = try await Window.getOrRegister(windowId: 788, app: TestApp.shared)
        let unwrappedWindow = try XCTUnwrap(window)

        XCTAssertTrue(unwrappedWindow.parent?.nodeWorkspace === mainWorkspace)
        assertEquals(unwrappedWindow.lastKnownSize, rect.size)
    }

    func testWindowRegistrationReturnsNilWhenSnapshotDisappeared() async throws {
        TestApp.shared.setWindowRegistrationSnapshot(windowId: 789, nil)

        let window = try await Window.getOrRegister(windowId: 789, app: TestApp.shared)

        XCTAssertNil(window)
        XCTAssertNil(Window.get(byPlatformWindowId: 789))
    }
}
