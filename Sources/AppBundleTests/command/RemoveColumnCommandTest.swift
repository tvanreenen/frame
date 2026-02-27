@testable import AppBundle
import Common
import XCTest

@MainActor
final class RemoveColumnCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testRemoveColumn_removesLastColumn_movesWindowsToLeftNeighbor() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col1)
        TestWindow.new(id: 2, parent: col2)
        assertEquals(w1.focusWindow(), true)

        try await RemoveColumnCommand(args: RemoveColumnCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)

        // col2 (last) is removed; its window is appended to col1 (left neighbor)
        assertEquals(workspace.columns.count, 1)
        assertEquals(workspace.allLeafWindowsRecursive.count, 2)
        assertEquals(col1.children.map { ($0 as! Window).windowId }, [1, 2])
    }

    func testRemoveColumn_multipleWindowsInLastColumn_allMovedToNeighbor() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col1)
        TestWindow.new(id: 2, parent: col2)
        TestWindow.new(id: 3, parent: col2)
        assertEquals(w1.focusWindow(), true)

        try await RemoveColumnCommand(args: RemoveColumnCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.columns.count, 1)
        assertEquals(workspace.allLeafWindowsRecursive.count, 3)
    }

    func testRemoveColumn_singleColumn_windowBecomesFloating() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col)
        assertEquals(w1.focusWindow(), true)

        try await RemoveColumnCommand(args: RemoveColumnCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)

        // Only column removed; window becomes a floating child of the workspace
        assertEquals(workspace.columns.count, 0)
        assertEquals(workspace.allLeafWindowsRecursive.count, 1)
    }
}
