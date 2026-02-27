@testable import AppBundle
import Common
import XCTest

@MainActor
final class SwapCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testSwap_swapWindows_Directional() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        let col1 = Column.newVTiles(parent: root, adaptiveWeight: 1)
        assertEquals(TestWindow.new(id: 1, parent: col1).focusWindow(), true)
        TestWindow.new(id: 2, parent: col1)
        let col2 = Column.newVTiles(parent: root, adaptiveWeight: 1)
        TestWindow.new(id: 3, parent: col2)

        try await SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .right)).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(3), .window(2)]),
                               .v_tiles([.window(1)])]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        try await SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .left)).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(1), .window(2)]),
                               .v_tiles([.window(3)])]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        try await SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .down)).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(2), .window(1)]),
                               .v_tiles([.window(3)])]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        try await SwapCommand(args: SwapCmdArgs(rawArgs: [], target: .up)).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription,
                     .h_tiles([.v_tiles([.window(1), .window(2)]),
                               .v_tiles([.window(3)])]))
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testSwap_DirectionalWrapping() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        let col1 = Column.newVTiles(parent: root, adaptiveWeight: 1)
        assertEquals(TestWindow.new(id: 1, parent: col1).focusWindow(), true)
        let col2 = Column.newVTiles(parent: root, adaptiveWeight: 1)
        TestWindow.new(id: 2, parent: col2)
        let col3 = Column.newVTiles(parent: root, adaptiveWeight: 1)
        TestWindow.new(id: 3, parent: col3)

        var args = SwapCmdArgs(rawArgs: [], target: .left)
        args.wrapAround = true
        try await SwapCommand(args: args).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.v_tiles([.window(3)]), .v_tiles([.window(2)]), .v_tiles([.window(1)])]))
        assertEquals(focus.windowOrNil?.windowId, 1)

        args.target = .initialized(.right)
        try await SwapCommand(args: args).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.v_tiles([.window(1)]), .v_tiles([.window(2)]), .v_tiles([.window(3)])]))
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testSwap_SwapFocus() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer
        let col1 = Column.newVTiles(parent: root, adaptiveWeight: 1)
        TestWindow.new(id: 1, parent: col1)
        assertEquals(TestWindow.new(id: 2, parent: col1).focusWindow(), true)
        let col2 = Column.newVTiles(parent: root, adaptiveWeight: 1)
        TestWindow.new(id: 3, parent: col2)

        var args = SwapCmdArgs(rawArgs: [], target: .right)
        args.swapFocus = true
        try await SwapCommand(args: args).run(.defaultEnv, .emptyStdin)
        assertEquals(root.layoutDescription, .h_tiles([.v_tiles([.window(1), .window(3)]), .v_tiles([.window(2)])]))
        assertEquals(focus.windowOrNil?.windowId, 3)
    }
}
