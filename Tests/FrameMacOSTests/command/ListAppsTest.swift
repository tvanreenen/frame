@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import XCTest
import FrameTestSupport

final class ListAppsTest: XCTestCase {
    func testParse() {
        assertNotNil(parseCommand("list-apps --macos-native-hidden").cmdOrNil)
        assertNotNil(parseCommand("list-apps --macos-native-hidden no").cmdOrNil)
        assertNotNil(parseCommand("list-apps --count").cmdOrNil)
        XCTAssertTrue((parseCommand("list-apps --format %{app-bundle-id}").errorOrNil ?? "").contains("Unknown flag '--format'"))
    }
}
