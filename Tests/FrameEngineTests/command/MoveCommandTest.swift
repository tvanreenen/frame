@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import XCTest
import FrameTestSupport

@MainActor
final class MoveCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    // MARK: - left/right: move between columns

    func testMove_rightToAdjacentColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col1)
        _ = TestWindow.new(id: 2, parent: col2)
        assertEquals(w1.focusWindow(), true)

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)

        assertEquals(col1.children.count, 0)
        assertEquals(col2.children.map { ($0 as! Window).windowId }, [2, 1])
    }

    func testMove_leftToAdjacentColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        TestWindow.new(id: 1, parent: col1)
        let w2 = TestWindow.new(id: 2, parent: col2)
        assertEquals(w2.focusWindow(), true)

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)

        assertEquals(col2.children.count, 0)
        assertEquals(col1.children.map { ($0 as! Window).windowId }, [1, 2])
    }

    func testMove_rightAtEdge_createsImplicitColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col1)
        TestWindow.new(id: 2, parent: col1)
        assertEquals(w1.focusWindow(), true)

        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.columns.count, 2)
        assertEquals(workspace.columns[0].children.map { ($0 as! Window).windowId }, [2])
        assertEquals(workspace.columns[1].children.map { ($0 as! Window).windowId }, [1])
        assertEquals(result.exitCode, 0)
    }

    func testMove_leftAtEdge_createsImplicitColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col1)
        TestWindow.new(id: 2, parent: col1)
        assertEquals(w1.focusWindow(), true)

        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.columns.count, 2)
        assertEquals(workspace.columns[0].children.map { ($0 as! Window).windowId }, [1])
        assertEquals(workspace.columns[1].children.map { ($0 as! Window).windowId }, [2])
        assertEquals(result.exitCode, 0)
    }

    func testMove_leftAtEdge_stopActionStops() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col1)
        assertEquals(w1.focusWindow(), true)

        var args = MoveCmdArgs(rawArgs: [], .left)
        args.rawBoundariesAction = .stop
        let result = try await MoveCommand(args: args).run(.defaultEnv, .emptyStdin)

        assertEquals(workspace.columns.count, 1)
        assertEquals(col1.children.count, 1)
        assertEquals(result.exitCode, 0)
    }

    // MARK: - up/down: reorder within column

    func testMove_downWithinColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col)
        _ = TestWindow.new(id: 2, parent: col)
        assertEquals(w1.focusWindow(), true)

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .down)).run(.defaultEnv, .emptyStdin)

        assertEquals(col.children.map { ($0 as! Window).windowId }, [2, 1])
    }

    func testMove_upWithinColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: col)
        let w2 = TestWindow.new(id: 2, parent: col)
        assertEquals(w2.focusWindow(), true)

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.defaultEnv, .emptyStdin)

        assertEquals(col.children.map { ($0 as! Window).windowId }, [2, 1])
    }

    func testMove_downAtBottomOfColumn_stops() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 1, parent: col)
        let w2 = TestWindow.new(id: 2, parent: col)
        assertEquals(w2.focusWindow(), true)

        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .down)).run(.defaultEnv, .emptyStdin)

        assertEquals(col.children.map { ($0 as! Window).windowId }, [1, 2])
        assertEquals(result.exitCode, 0)
    }

    func testMove_upAtTopOfColumn_stops() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col)
        _ = TestWindow.new(id: 2, parent: col)
        assertEquals(w1.focusWindow(), true)

        let result = try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .up)).run(.defaultEnv, .emptyStdin)

        assertEquals(col.children.map { ($0 as! Window).windowId }, [1, 2])
        assertEquals(result.exitCode, 0)
    }

    func testMove_emptyColumnRemovedAfterMove() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col1)
        TestWindow.new(id: 2, parent: col2)
        assertEquals(w1.focusWindow(), true)

        try await MoveCommand(args: MoveCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin)

        // w1 moved to col2, leaving col1 empty. Normalization removes the empty column.
        assertEquals(workspace.columns.count, 1)
        assertEquals(workspace.columns.first?.children.map { ($0 as! Window).windowId }, [2, 1])
    }
}

extension TreeNode {
    var layoutDescription: LayoutDescription {
        if let window = self as? Window {
            return .window(window.windowId)
        }
        if let workspace = self as? Workspace {
            return .workspace(workspace.children.map(\.layoutDescription))
        }
        if self is NativeMinimizedWindowsContainer { return .nativeMinimized }
        if self is NativeFullscreenWindowsContainer { return .nativeFullscreen }
        if self is HiddenAppWindowsContainer { return .hiddenAppWindow }
        if self is PopupWindowsContainer { return .popupWindowsContainer }
        guard let container = self as? Column else { die("Unknown tree \(self)") }
        return container.orientation == .h
            ? .h_tiles(container.children.map(\.layoutDescription))
            : .v_tiles(container.children.map(\.layoutDescription))
    }
}

enum LayoutDescription: Equatable {
    case workspace([LayoutDescription])
    case h_tiles([LayoutDescription])
    case v_tiles([LayoutDescription])
    case window(UInt32)
    case popupWindowsContainer
    case nativeMinimized
    case hiddenAppWindow
    case nativeFullscreen
}
