@testable import AppBundle
import Common
import XCTest

@MainActor
final class ExecCommandTest: XCTestCase {
    func testRemovedCommandsAreRejected() {
        let execErr = parseCommand("exec-and-forget echo 'foo'").errorOrNil ?? ""
        XCTAssertTrue(execErr.contains("exec-and-forget"), execErr)

        let envErr = parseCommand("list-exec-env-vars").errorOrNil ?? ""
        XCTAssertTrue(envErr.contains("list-exec-env-vars"), envErr)
    }
}
