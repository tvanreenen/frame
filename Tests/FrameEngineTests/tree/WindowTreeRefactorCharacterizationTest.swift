@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import XCTest
import FrameTestSupport

@MainActor
final class WindowTreeRefactorCharacterizationTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testMoveWindowToWorkspace_tiledWindowBindsDirectlyIntoLastTargetColumn() {
        let sourceWorkspace = Workspace.get(byName: "a")
        let sourceColumn = Column.newVTiles(parent: sourceWorkspace.columnsRoot, adaptiveWeight: 1)
        let window = TestWindow.new(id: 1, parent: sourceColumn)
        let targetWorkspace = Workspace.get(byName: "b")
        _ = Column.newVTiles(parent: targetWorkspace.columnsRoot, adaptiveWeight: 1).apply {
            _ = TestWindow.new(id: 2, parent: $0)
        }
        let lastTargetColumn = Column.newVTiles(parent: targetWorkspace.columnsRoot, adaptiveWeight: 1).apply {
            _ = TestWindow.new(id: 3, parent: $0)
        }
        let io = CmdIo(stdin: .emptyStdin)
        let didMove = moveWindowToWorkspace(window, targetWorkspace, io, focusFollowsWindow: false, failIfNoop: false)

        XCTAssertTrue(didMove)
        XCTAssertTrue(window.parent === lastTargetColumn)
        XCTAssertTrue(targetWorkspace.columnsRoot.children.allSatisfy { $0 is Column })
        assertColumnChildren(targetWorkspace, [[2], [3, 1]])
    }

    func testRestoreClosedWindowsCache_restoresColumnsStructure() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.columnsRoot
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: col1).focusWindow()
        _ = TestWindow.new(id: 2, parent: col1)
        _ = TestWindow.new(id: 3, parent: col2)
        cacheClosedWindowIfNeeded()

        for workspace in Workspace.all {
            clearWorkspaceChildrenForTests(workspace)
        }
        Window.resetForTests()
        TestApp.shared.resetState()

        let detectedColumn = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let restoredWindow = TestWindow.new(id: 1, parent: detectedColumn)
        _ = TestWindow.new(id: 2, parent: detectedColumn)
        _ = TestWindow.new(id: 3, parent: detectedColumn)
        let didRestore = try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: restoredWindow)
        XCTAssertTrue(didRestore)
        XCTAssertTrue(workspace.columnsRoot === root)
        assertEquals(workspace.columns.count, 2)
        assertEquals(workspace.columns[0].children.compactMap { ($0 as? Window)?.windowId }, [1, 2])
        assertEquals(workspace.columns[1].children.compactMap { ($0 as? Window)?.windowId }, [3])
        XCTAssertTrue(workspace.columnsRoot.children.allSatisfy { $0 is Column })
    }

    func testFrozenWorkspaceSnapshot_usesColumnsModel() {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 2)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 3)
        _ = TestWindow.new(id: 11, parent: col1, adaptiveWeight: 4)
        _ = TestWindow.new(id: 12, parent: col1, adaptiveWeight: 5)
        _ = TestWindow.new(id: 13, parent: col2, adaptiveWeight: 6)

        let frozen = FrozenWorkspace(workspace)

        assertEquals(frozen.columns.count, 2)
        assertEquals(frozen.columns[0].windows.map(\.id), [11, 12])
        assertEquals(frozen.columns[1].windows.map(\.id), [13])
        assertEquals(frozen.columns.map(\.weight), [2, 3])
        assertEquals(frozen.columns[0].windows.map(\.weight), [4, 5])
        assertEquals(frozen.columns[1].windows.map(\.weight), [6])
    }

    func testNormalizeLayoutReason_restoresTiledFullscreenWindowToColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let window = TestWindow.new(id: 1, parent: column)
        _ = window.focusWindow()

        TestApp.shared.setNativeFullscreen(windowId: 1, true)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is NativeFullscreenWindowsContainer)
        assertPreviousPlacement(window.layoutReason, expected: .tiled)

        TestApp.shared.setNativeFullscreen(windowId: 1, false)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is Column)
        assertColumnChildren(workspace, [[], [1]])
    }

    func testNormalizeLayoutReason_reclassifiesExcludedFullscreenWindow() async throws {
        let window = TestWindow.new(id: 2, parent: excludedWindowsContainer)
        _ = window.focusWindow()

        TestApp.shared.setNativeFullscreen(windowId: 2, true)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is NativeFullscreenWindowsContainer)
        assertPreviousPlacement(window.layoutReason, expected: .reclassify)

        TestApp.shared.setNativeFullscreen(windowId: 2, false)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is Column || window.parent is ExcludedWindowsContainer)
    }

    func testNormalizeLayoutReason_restoresTiledMinimizedWindowToColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let column = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let window = TestWindow.new(id: 3, parent: column)
        _ = window.focusWindow()

        TestApp.shared.setNativeMinimized(windowId: 3, true)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is NativeMinimizedWindowsContainer)
        assertPreviousPlacement(window.layoutReason, expected: .tiled)

        TestApp.shared.setNativeMinimized(windowId: 3, false)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is Column)
        assertColumnChildren(workspace, [[], [3]])
    }

    func testNormalizeLayoutReason_reclassifiesExcludedMinimizedWindow() async throws {
        let window = TestWindow.new(id: 4, parent: excludedWindowsContainer)
        _ = window.focusWindow()

        TestApp.shared.setNativeMinimized(windowId: 4, true)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is NativeMinimizedWindowsContainer)
        assertPreviousPlacement(window.layoutReason, expected: .reclassify)

        TestApp.shared.setNativeMinimized(windowId: 4, false)
        try await normalizeLayoutReason()

        XCTAssertTrue(window.parent is Column || window.parent is ExcludedWindowsContainer)
    }
}

private func assertPreviousPlacement(_ layoutReason: LayoutReason, expected: PreviousWindowPlacement, file: StaticString = #filePath, line: UInt = #line) {
    switch layoutReason {
        case .standard:
            XCTFail("Expected platform-displaced layout reason", file: file, line: line)
        case .platformDisplaced(let actual):
            assertEquals(actual, expected)
    }
}

@MainActor
private func assertColumnChildren(_ workspace: Workspace, _ expected: [[FrameWindowId]], file: String = #filePath, line: Int = #line) {
    let actual = workspace.columns.map { column in
        column.children.compactMap { ($0 as? Window)?.windowId }
    }
    assertEquals(actual, expected, file: file, line: line)
}
