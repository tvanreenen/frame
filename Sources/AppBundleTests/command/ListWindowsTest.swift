@testable import AppBundle
import Common
import XCTest

@MainActor
final class ListWindowsTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertEquals(parseCommand("list-windows --pid 1").errorOrNil, "Mandatory option is not specified (--focused|--monitor|--workspace)")
        assertNil(parseCommand("list-windows --workspace M --pid 1").errorOrNil)
        assertEquals(parseCommand("list-windows --pid 1 --focused").errorOrNil, "--focused conflicts with other \"filtering\" flags")
        assertNil(parseCommand("list-windows --monitor all").errorOrNil)
        assertNil(parseCommand("list-windows --monitor mouse").errorOrNil)
        XCTAssertTrue((parseCommand("list-windows --all").errorOrNil ?? "").contains("Unknown flag '--all'"))
        XCTAssertTrue((parseCommand("list-windows --app-id com.apple.Terminal --monitor all").errorOrNil ?? "").contains("Unknown flag '--app-id'"))

        // --json
        assertEquals(parseCommand("list-windows --monitor all --count --json").errorOrNil, "ERROR: Conflicting options: --count, --json")
        XCTAssertTrue((parseCommand("list-windows --monitor all --format %{window-title}").errorOrNil ?? "").contains("Unknown flag '--format'"))
    }
}
