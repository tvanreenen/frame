@testable import AppBundle
import Common
import XCTest

final class ListWorkspacesTest: XCTestCase {
    func testParse() {
        assertNotNil(parseCommand("list-workspaces --monitor all").cmdOrNil)
        assertNil(parseCommand("list-workspaces --visible").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --visible --monitor 2").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --monitor focused").cmdOrNil)
        assertNotNil(parseCommand("list-workspaces --monitor focused --visible").cmdOrNil)
        XCTAssertTrue((parseCommand("list-workspaces --all").errorOrNil ?? "").contains("Unknown flag '--all'"))
        XCTAssertTrue((parseCommand("list-workspaces --focused").errorOrNil ?? "").contains("Unknown flag '--focused'"))
        XCTAssertTrue((parseCommand("list-workspaces --monitor all --format %{workspace}").errorOrNil ?? "").contains("Unknown flag '--format'"))
        assertEquals(parseCommand("list-workspaces --empty").errorOrNil, "Mandatory option is not specified (--monitor)")
    }
}
