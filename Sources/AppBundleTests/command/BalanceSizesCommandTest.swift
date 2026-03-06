@testable import AppBundle
import Common
import XCTest

@MainActor
final class BalanceSizesCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testBalanceSizesCommand() async throws {
        let workspace = Workspace.get(byName: name).apply { wsp in
            wsp.columnsRoot.apply {
                TestWindow.new(id: 1, parent: $0).setWeight(wsp.columnsRoot.orientation, 1)
                TestWindow.new(id: 2, parent: $0).setWeight(wsp.columnsRoot.orientation, 2)
                TestWindow.new(id: 3, parent: $0).setWeight(wsp.columnsRoot.orientation, 3)
            }
        }

        try await BalanceSizesCommand(args: BalanceSizesCmdArgs(rawArgs: []))
            .run(.defaultEnv.copy(\.workspaceName, name), .emptyStdin)

        for window in workspace.columnsRoot.children {
            assertEquals(window.getWeight(workspace.columnsRoot.orientation), 1)
        }
    }
}
