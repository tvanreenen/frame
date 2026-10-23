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

    func testWindowRegistrationCreatesFirstColumnInEmptyWorkspace() async throws {
        let workspace = Workspace.get(byName: name)
        check(workspace.focusWorkspace())

        let registeredWindow = try await Window.getOrRegister(windowId: 1, app: TestApp.shared)
        let window = try XCTUnwrap(registeredWindow)

        assertEquals(workspace.columns.count, 1)
        XCTAssertTrue(window.parent === workspace.columns.first)
        assertEquals(window.indexInColumn, 0)
    }

    func testWindowRegistrationCreatesSecondColumnThenAppendsToFocusedColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let firstColumn = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: firstColumn).focusWindow()

        let registeredSecondWindow = try await Window.getOrRegister(windowId: 2, app: TestApp.shared)
        let secondWindow = try XCTUnwrap(registeredSecondWindow)

        assertEquals(workspace.columns.count, 2)
        XCTAssertTrue(workspace.columns.first === firstColumn)
        XCTAssertTrue(secondWindow.parent === workspace.columns.last)
        assertEquals(firstColumn.children.compactMap { ($0 as? Window)?.windowId }, [1])

        check(secondWindow.focusWindow())
        let registeredThirdWindow = try await Window.getOrRegister(windowId: 3, app: TestApp.shared)
        let thirdWindow = try XCTUnwrap(registeredThirdWindow)

        assertEquals(workspace.columns.count, 2)
        XCTAssertTrue(thirdWindow.parent === secondWindow.parent)
        assertEquals(workspace.columns.last?.children.compactMap { ($0 as? Window)?.windowId }, [secondWindow.windowId, thirdWindow.windowId])
    }

    func testWindowRegistrationCreatesSecondColumnWhenOnlyColumnHasMultipleWindows() async throws {
        let workspace = Workspace.get(byName: name)
        let firstColumn = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: firstColumn).focusWindow()
        _ = TestWindow.new(id: 2, parent: firstColumn)

        let registeredWindow = try await Window.getOrRegister(windowId: 3, app: TestApp.shared)
        let window = try XCTUnwrap(registeredWindow)

        assertEquals(workspace.columns.count, 2)
        XCTAssertTrue(workspace.columns.first === firstColumn)
        XCTAssertTrue(window.parent === workspace.columns.last)
        assertEquals(firstColumn.children.compactMap { ($0 as? Window)?.windowId }, [1, 2])
    }

    func testWindowRegistrationAppendsToOnlyColumnOnPortraitMonitor() async throws {
        configureMonitor(rect: Rect(topLeftX: 0, topLeftY: 0, width: 1080, height: 1920))
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: column).focusWindow()

        let registeredWindow = try await Window.getOrRegister(windowId: 2, app: TestApp.shared)
        let window = try XCTUnwrap(registeredWindow)

        assertEquals(workspace.columns.count, 1)
        XCTAssertTrue(window.parent === column)
        assertEquals(column.children.compactMap { ($0 as? Window)?.windowId }, [1, window.windowId])
    }

    func testWindowRegistrationAppendsToOnlyColumnOnSquareMonitor() async throws {
        configureMonitor(rect: Rect(topLeftX: 0, topLeftY: 0, width: 1200, height: 1200))
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: column).focusWindow()

        let registeredWindow = try await Window.getOrRegister(windowId: 2, app: TestApp.shared)
        let window = try XCTUnwrap(registeredWindow)

        assertEquals(workspace.columns.count, 1)
        XCTAssertTrue(window.parent === column)
        assertEquals(column.children.compactMap { ($0 as? Window)?.windowId }, [1, window.windowId])
    }

    func testWindowRegistrationUsesFullMonitorDimensionsForSecondColumnPlacement() async throws {
        configureMonitor(
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 900, height: 1080),
        )
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: column).focusWindow()

        let registeredWindow = try await Window.getOrRegister(windowId: 2, app: TestApp.shared)
        let window = try XCTUnwrap(registeredWindow)

        assertEquals(workspace.columns.count, 2)
        XCTAssertTrue(workspace.columns.first === column)
        XCTAssertTrue(window.parent === workspace.columns.last)
        assertEquals(column.children.compactMap { ($0 as? Window)?.windowId }, [1])
    }

    func testExcludedWindowRegistrationDoesNotCreateSecondColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: column).focusWindow()
        TestApp.shared.setWindowPlacementKind(windowId: 2, .excluded)

        let registeredWindow = try await Window.getOrRegister(windowId: 2, app: TestApp.shared)
        let window = try XCTUnwrap(registeredWindow)

        assertEquals(workspace.columns.count, 1)
        XCTAssertTrue(window.parent === excludedWindowsContainer)
    }

    func testWindowRegistrationUsesFocusedColumnForNewTilingPlacement() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 785, parent: col1).focusWindow()
        _ = TestWindow.new(id: 786, parent: col2)
        _ = TestWindow.new(id: 790, parent: col1)
        _ = TestWindow.new(id: 791, parent: col1)

        let window = try await Window.getOrRegister(windowId: 787, app: TestApp.shared)
        let unwrappedWindow = try XCTUnwrap(window)

        assertEquals(workspace.columns.count, 2)
        XCTAssertTrue(unwrappedWindow.parent === col1)
        assertEquals(col1.children.compactMap { ($0 as? Window)?.windowId }, [785, 790, 791, unwrappedWindow.windowId])
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

    private func configureMonitor(rect: Rect, visibleRect: Rect? = nil) {
        let monitor = RegistrationTestMonitor(
            systemMonitorIndex: 1,
            name: "Test Monitor",
            rect: rect,
            visibleRect: visibleRect ?? rect,
            isMain: true,
        )
        currentSession.platformServices.mainMonitor = { monitor }
        currentSession.platformServices.monitors = { [monitor] }
    }
}
