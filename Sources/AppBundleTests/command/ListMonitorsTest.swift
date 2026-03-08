@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import XCTest

final class ListMonitorsTest: XCTestCase {
    func testParseListMonitorsCommand() {
        testParseCommandSucc("list-monitors", ListMonitorsCmdArgs(rawArgs: []))
        testParseCommandSucc("list-monitors --focused", ListMonitorsCmdArgs(rawArgs: []).copy(\.focused, true))
        testParseCommandSucc("list-monitors --count", ListMonitorsCmdArgs(rawArgs: []).copy(\.outputOnlyCount, true))
        XCTAssertTrue((parseCommand("list-monitors --format %{monitor-id}").errorOrNil ?? "").contains("Unknown flag '--format'"))
    }
}
