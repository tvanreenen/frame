@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import XCTest
import FrameTestSupport

@MainActor
final class ResizeBehaviorTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testResize_width_growsNonLastColumn() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 10)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 10)
        let w1 = TestWindow.new(id: 1, parent: col1)
        TestWindow.new(id: 2, parent: col2)
        assertEquals(w1.focusWindow(), true)

        try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(5))).run(.defaultEnv, .emptyStdin)

        // col1 is non-last → directionSign=+1 → weight grows
        XCTAssertGreaterThan(col1.getWeight(.h), 10.0)
        XCTAssertLessThan(col2.getWeight(.h), 10.0)
    }

    func testResize_width_lastColumnDirectionFlip() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 10)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 10)
        TestWindow.new(id: 1, parent: col1)
        let w2 = TestWindow.new(id: 2, parent: col2)
        assertEquals(w2.focusWindow(), true)

        try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(5))).run(.defaultEnv, .emptyStdin)

        // col2 is last → directionSign=-1 → "add" shrinks the column (moves left edge left)
        XCTAssertGreaterThan(col1.getWeight(.h), 10.0)
        XCTAssertLessThan(col2.getWeight(.h), 10.0)
    }

    func testResize_height_growsNonLastWindow() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col, adaptiveWeight: 10)
        TestWindow.new(id: 2, parent: col, adaptiveWeight: 10)
        assertEquals(w1.focusWindow(), true)

        try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .add(5))).run(.defaultEnv, .emptyStdin)

        // w1 is non-last → directionSign=+1 → height grows
        XCTAssertGreaterThan(w1.getWeight(.v), 10.0)
    }

    func testResize_height_lastWindowDirectionFlip() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        TestWindow.new(id: 1, parent: col, adaptiveWeight: 10)
        let w2 = TestWindow.new(id: 2, parent: col, adaptiveWeight: 10)
        assertEquals(w2.focusWindow(), true)

        try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .height, units: .add(5))).run(.defaultEnv, .emptyStdin)

        // w2 is last → directionSign=-1 → "add" shrinks its height (moves top edge up)
        XCTAssertLessThan(w2.getWeight(.v), 10.0)
    }

    func testResize_width_singleColumn_isNoOp() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col)
        assertEquals(w1.focusWindow(), true)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(10))).run(.defaultEnv, .emptyStdin)

        // Single column: no siblings to redistribute weight to → returns false
        assertEquals(result.exitCode, 1)
        assertEquals(col.getWeight(.h), 1.0)
    }

    func testResize_focusedFloatingWindow_isSilentNoOp() async throws {
        let workspace = Workspace.get(byName: name)
        let floating = TestWindow.new(id: 42, parent: workspace)
        assertEquals(floating.focusWindow(), true)

        let result = try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .width, units: .add(10))).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        assertEquals(result.stderr, [])
    }

    func testResize_smart_resizesWindowHeight() async throws {
        let workspace = Workspace.get(byName: name)
        let col = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let w1 = TestWindow.new(id: 1, parent: col, adaptiveWeight: 10)
        TestWindow.new(id: 2, parent: col, adaptiveWeight: 10)
        assertEquals(w1.focusWindow(), true)

        try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(5))).run(.defaultEnv, .emptyStdin)

        // smart picks candidates.first = window; parent = v-tiles column → resizes height
        XCTAssertGreaterThan(w1.getWeight(.v), 10.0)
        assertEquals(col.getWeight(.h), 1.0)
    }

    func testResize_smartOpposite_resizesColumnWidth() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 10)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 10)
        let w1 = TestWindow.new(id: 1, parent: col1, adaptiveWeight: 10)
        TestWindow.new(id: 2, parent: col1, adaptiveWeight: 10)
        TestWindow.new(id: 3, parent: col2)
        assertEquals(w1.focusWindow(), true)

        try await ResizeCommand(args: ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .add(5))).run(.defaultEnv, .emptyStdin)

        // smart-opposite: opposite of v-tiles parent = h → picks col1 (h-tiles parent = root) → resizes width
        XCTAssertGreaterThan(col1.getWeight(.h), 10.0)
        assertEquals(w1.getWeight(.v), 10.0)
    }
}

final class ResizeCommandTest: XCTestCase {
    func testParseCommand() {
        testParseCommandSucc("resize smart +10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .add(10)))
        testParseCommandSucc("resize smart -10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .subtract(10)))
        testParseCommandSucc("resize smart 10", ResizeCmdArgs(rawArgs: [], dimension: .smart, units: .set(10)))

        testParseCommandSucc("resize smart-opposite +10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .add(10)))
        testParseCommandSucc("resize smart-opposite -10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .subtract(10)))
        testParseCommandSucc("resize smart-opposite 10", ResizeCmdArgs(rawArgs: [], dimension: .smartOpposite, units: .set(10)))

        testParseCommandSucc("resize height 10", ResizeCmdArgs(rawArgs: [], dimension: .height, units: .set(10)))
        testParseCommandSucc("resize width 10", ResizeCmdArgs(rawArgs: [], dimension: .width, units: .set(10)))

        testParseCommandFail("resize s 10", msg: """
            ERROR: Can't parse 's'.
                   Possible values: (width|height|smart|smart-opposite)
            """)
        testParseCommandFail("resize smart foo", msg: "ERROR: <number> argument must be a number")
    }
}
