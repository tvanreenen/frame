@testable import AppBundle
import Common
import XCTest

@MainActor
final class FlattenWorkspaceTreeCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSimple() async throws {
        let workspace = Workspace.get(byName: name).apply {
            // Two columns: col1 → [w1], col2 → [w2]
            let col1 = TilingContainer.newVTiles(parent: $0.columnsRoot, adaptiveWeight: 1)
            let col2 = TilingContainer.newVTiles(parent: $0.columnsRoot, adaptiveWeight: 1)
            TestWindow.new(id: 1, parent: col1)
            TestWindow.new(id: 2, parent: col2)
            TestWindow.new(id: 3, parent: $0) // floating
        }
        assertEquals(workspace.focusWorkspace(), true)

        try await FlattenWorkspaceTreeCommand(args: FlattenWorkspaceTreeCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)
        // FlattenWorkspaceTreeCommand moves all windows into rootTilingContainer directly
        // normalizeContainers then collects them into a single column
        workspace.normalizeContainers()
        // Both windows end up in one column, floating remains
        assertEquals(workspace.columns.count, 1)
        assertEquals(workspace.columns.first?.children.count, 2)
        assertEquals(workspace.floatingWindows.count, 1)
    }
}
