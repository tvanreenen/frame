@testable import AppBundle
import Common
import XCTest

@MainActor
final class WindowTreeRefactorCharacterizationTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testMoveWindowToWorkspace_tiledWindowCurrentlyLandsAsRootChildBeforeNormalization() {
        let sourceWorkspace = Workspace.get(byName: "a")
        let sourceColumn = Column.newVTiles(parent: sourceWorkspace.columnsRoot, adaptiveWeight: 1)
        let window = TestWindow.new(id: 1, parent: sourceColumn)
        let io = CmdIo(stdin: .emptyStdin)
        let didMove = moveWindowToWorkspace(window, Workspace.get(byName: "b"), io, focusFollowsWindow: false, failIfNoop: false)

        let targetWorkspace = Workspace.get(byName: "b")
        XCTAssertTrue(didMove)
        assertEquals(targetWorkspace.columns.count, 0)
        assertEquals(targetWorkspace.rootTilingContainer.children.count, 1)
        XCTAssertTrue(targetWorkspace.rootTilingContainer.children.first is Window)
        assertEquals((targetWorkspace.rootTilingContainer.children.first as? Window)?.windowId, 1)
    }

    func testRestoreClosedWindowsCache_restoresColumnsStructure() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: col1).focusWindow()
        _ = TestWindow.new(id: 2, parent: col1)
        _ = TestWindow.new(id: 3, parent: col2)
        _ = TestWindow.new(id: 4, parent: workspace)

        cacheClosedWindowIfNeeded()

        for workspace in Workspace.all {
            for child in Array(workspace.children) {
                child.unbindFromParent()
            }
        }
        Window.resetForTests()
        TestApp.shared.resetState()

        let restoredWindow = TestWindow.new(id: 1, parent: workspace)
        _ = TestWindow.new(id: 2, parent: workspace)
        _ = TestWindow.new(id: 3, parent: workspace)
        _ = TestWindow.new(id: 4, parent: workspace)

        let didRestore = try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: restoredWindow)
        XCTAssertTrue(didRestore)
        assertEquals(workspace.columns.count, 2)
        assertEquals(workspace.columns[0].children.compactMap { ($0 as? Window)?.windowId }, [1, 2])
        assertEquals(workspace.columns[1].children.compactMap { ($0 as? Window)?.windowId }, [3])
        assertEquals(workspace.floatingWindows.map(\.windowId), [4])
        XCTAssertTrue(workspace.rootTilingContainer.children.allSatisfy { $0 is Column })
    }

    func testNormalizeLayoutReason_restoresTiledFullscreenWindowToColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let window = TestWindow.new(id: 1, parent: column)
        _ = window.focusWindow()

        TestApp.shared.setMacosFullscreen(windowId: 1, true)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is MacosFullscreenWindowsContainer)
        assertPreviousPlacement(window.layoutReason, expected: .tilingContainer)

        TestApp.shared.setMacosFullscreen(windowId: 1, false)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is Column)
        assertColumnChildren(workspace, [[], [1]])
    }

    func testNormalizeLayoutReason_restoresFloatingFullscreenWindowToWorkspace() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 2, parent: workspace)
        _ = window.focusWindow()

        TestApp.shared.setMacosFullscreen(windowId: 2, true)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is MacosFullscreenWindowsContainer)
        assertPreviousPlacement(window.layoutReason, expected: .workspace)

        TestApp.shared.setMacosFullscreen(windowId: 2, false)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is Workspace)
        assertEquals(workspace.floatingWindows.map(\.windowId), [2])
    }

    func testNormalizeLayoutReason_restoresTiledMinimizedWindowToColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let window = TestWindow.new(id: 3, parent: column)
        _ = window.focusWindow()

        TestApp.shared.setMacosMinimized(windowId: 3, true)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is MacosMinimizedWindowsContainer)
        assertPreviousPlacement(window.layoutReason, expected: .tilingContainer)

        TestApp.shared.setMacosMinimized(windowId: 3, false)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is Column)
        assertColumnChildren(workspace, [[], [3]])
    }

    func testNormalizeLayoutReason_restoresFloatingMinimizedWindowToWorkspace() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 4, parent: workspace)
        _ = window.focusWindow()

        TestApp.shared.setMacosMinimized(windowId: 4, true)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is MacosMinimizedWindowsContainer)
        assertPreviousPlacement(window.layoutReason, expected: .workspace)

        TestApp.shared.setMacosMinimized(windowId: 4, false)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is Workspace)
        assertEquals(workspace.floatingWindows.map(\.windowId), [4])
    }
}

private func assertPreviousPlacement(_ layoutReason: LayoutReason, expected: NonLeafTreeNodeKind, file: StaticString = #filePath, line: UInt = #line) {
    switch layoutReason {
        case .standard:
            XCTFail("Expected macOS layout reason", file: file, line: line)
        case .macos(let actual):
            assertEquals(actual, expected)
    }
}

@MainActor
private func assertColumnChildren(_ workspace: Workspace, _ expected: [[UInt32]], file: String = #filePath, line: Int = #line) {
    let actual = workspace.columns.map { column in
        column.children.compactMap { ($0 as? Window)?.windowId }
    }
    assertEquals(actual, expected, file: file, line: line)
}
