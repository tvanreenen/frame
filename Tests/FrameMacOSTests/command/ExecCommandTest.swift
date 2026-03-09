@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import XCTest
import FrameTestSupport

@MainActor
final class ExecCommandTest: XCTestCase {
    func testRemovedCommandsAreRejected() {
        let execErr = parseCommand("exec-and-forget echo 'foo'").errorOrNil ?? ""
        XCTAssertTrue(execErr.contains("exec-and-forget"), execErr)

        let envErr = parseCommand("list-exec-env-vars").errorOrNil ?? ""
        XCTAssertTrue(envErr.contains("list-exec-env-vars"), envErr)

        let enableErr = parseCommand("enable off").errorOrNil ?? ""
        XCTAssertTrue(enableErr.contains("enable"), enableErr)

        let layoutErr = parseCommand("layout tiling").errorOrNil ?? ""
        XCTAssertTrue(layoutErr.contains("layout"), layoutErr)
    }

    func testCheckConfigCommandIsRejected() {
        let err = parseCommand("check-config").errorOrNil ?? ""
        XCTAssertTrue(err.contains("check-config"), err)
    }

    func testReloadConfigRemovedFlagsAreRejected() {
        let dryRunErr = parseCommand("reload-config --dry-run").errorOrNil ?? ""
        XCTAssertTrue(dryRunErr.contains("--dry-run"), dryRunErr)

        let noGuiErr = parseCommand("reload-config --no-gui").errorOrNil ?? ""
        XCTAssertTrue(noGuiErr.contains("--no-gui"), noGuiErr)
    }
}
