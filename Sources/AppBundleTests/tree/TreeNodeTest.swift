@testable import AppBundle
import XCTest

@MainActor
final class TreeNodeTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testChildParentCyclicReferenceMemoryLeak() {
        let workspace = Workspace.get(byName: name) // Don't cache root node
        let window = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)

        XCTAssertTrue(window.parent != nil)
        workspace.rootTilingContainer.unbindFromParent()
        XCTAssertTrue(window.parent == nil)
    }

    func testIsEffectivelyEmpty() {
        let workspace = Workspace.get(byName: name)

        XCTAssertTrue(workspace.isEffectivelyEmpty)
        weak let window: TestWindow? = .new(id: 1, parent: workspace.rootTilingContainer)
        XCTAssertNotEqual(window, nil)
        XCTAssertTrue(!workspace.isEffectivelyEmpty)
        window!.unbindFromParent()
        XCTAssertTrue(workspace.isEffectivelyEmpty)

        // Don't save to local variable
        TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        XCTAssertTrue(!workspace.isEffectivelyEmpty)
    }

    // MARK: - normalizeColumnsStructure tests

    func testNormalizeContainers_dontRemoveRoot() {
        let workspace = Workspace.get(byName: name)
        weak let root = workspace.rootTilingContainer
        XCTAssertNotEqual(root, nil)
        XCTAssertTrue(root!.isEffectivelyEmpty)
        workspace.normalizeContainers()
        // Root container is never unbound even when empty
        XCTAssertNotEqual(root, nil)
        XCTAssertTrue(root!.isEffectivelyEmpty)
    }

    func testNormalizeContainers_rootBecomesHTiles() {
        let workspace = Workspace.get(byName: name)
        // Force the root to v-orientation (shouldn't happen in normal use but must be handled)
        workspace.rootTilingContainer.setOrientation(.v)
        assertEquals(workspace.rootTilingContainer.orientation, .v)
        workspace.normalizeContainers()
        assertEquals(workspace.rootTilingContainer.orientation, .h)
    }

    func testNormalizeContainers_columnBecomesVTiles() {
        let workspace = Workspace.get(byName: name)
        // Create an h-tiles column (wrong orientation)
        let badColumn = TilingContainer.newHTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        TestWindow.new(id: 1, parent: badColumn)
        workspace.normalizeContainers()
        // After normalization, the column must be v-tiles
        assertEquals(workspace.columnsRoot.children.count, 1)
        let col = workspace.columnsRoot.children.first as? TilingContainer
        XCTAssertNotNil(col)
        assertEquals(col?.orientation, .v)
    }

    func testNormalizeContainers_removeEmptyColumn() {
        let workspace = Workspace.get(byName: name)
        // Create an empty column (no windows)
        _ = TilingContainer.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        assertEquals(workspace.columnsRoot.children.count, 1)
        workspace.normalizeContainers()
        // Empty column should be removed
        assertEquals(workspace.columnsRoot.children.count, 0)
    }

    func testNormalizeContainers_flattenNestedContainersIntoColumn() {
        let workspace = Workspace.get(byName: name)
        // Set up: root → col(v) → nested(h) → window(1)
        let col = TilingContainer.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let nested = TilingContainer.newHTiles(parent: col, adaptiveWeight: 1)
        TestWindow.new(id: 1, parent: nested)
        workspace.normalizeContainers()
        // The window should be lifted to be a direct child of the column
        assertEquals(col.children.count, 1)
        XCTAssertTrue(col.children.first is Window)
    }

    func testNormalizeContainers_orphanWindowMovedToLastColumn() {
        let workspace = Workspace.get(byName: name)
        // Set up: root → col(v) → window(1), root → orphan window(2)
        let col = TilingContainer.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        TestWindow.new(id: 1, parent: col)
        // Directly bind window to root (orphan — shouldn't happen normally)
        TestWindow.new(id: 2, parent: workspace.columnsRoot)
        workspace.normalizeContainers()
        // Orphan window(2) should be moved into the last column
        assertEquals(workspace.columns.count, 1)
        assertEquals(col.children.map { ($0 as! Window).windowId }, [1, 2])
    }
}
