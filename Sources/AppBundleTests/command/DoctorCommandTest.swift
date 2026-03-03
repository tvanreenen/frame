@testable import AppBundle
import Common
import XCTest

final class DoctorCommandTest: XCTestCase {
    func testParse() {
        testParseCommandSucc("doctor", DoctorCmdArgs(rawArgs: []))
        XCTAssertTrue((parseCommand("doctor --format foo").errorOrNil ?? "").contains("Unknown flag '--format'"))
    }
}
