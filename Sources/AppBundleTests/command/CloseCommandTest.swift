@testable import AppBundle
import Common
import XCTest

@MainActor
final class CloseCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSimple() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: col).focusWindow()
        TestWindow.new(id: 2, parent: col)

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(workspace.allLeafWindowsRecursive.count, 2)

        try await CloseCommand(args: CloseCmdArgs(rawArgs: [])).run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 2)
        assertEquals(workspace.allLeafWindowsRecursive.count, 1)
    }

    func testCloseViaWindowIdFlag() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: col).focusWindow()
        TestWindow.new(id: 2, parent: col)

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(workspace.allLeafWindowsRecursive.count, 2)

        try await CloseCommand(args: CloseCmdArgs(rawArgs: []).copy(\.windowId, 2)).run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(workspace.allLeafWindowsRecursive.count, 1)
    }
}
