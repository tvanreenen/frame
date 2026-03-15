@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import XCTest
import FrameTestSupport

@MainActor
final class DebugWindowEventsCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertNotNil(parseCommand("debug-window-events").cmdOrNil)
        XCTAssertTrue((parseCommand("debug-window-events on").errorOrNil ?? "").contains("Unknown argument 'on'"))
        XCTAssertTrue((parseCommand("debug-window-events off").errorOrNil ?? "").contains("Unknown argument 'off'"))
    }

    func testToggleUsesFrontmostAppThenTurnsOffWithoutRetargeting() async throws {
        currentSession.platformServices.frontmostAppBundleId = { "com.mitchellh.ghostty" }

        let enableResult = try await parseCommand("debug-window-events").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(enableResult.exitCode, 0)
        XCTAssertTrue((enableResult.stdout.first ?? "").contains("ON for com.mitchellh.ghostty"))

        currentSession.platformServices.frontmostAppBundleId = { "com.apple.Terminal" }

        let disableResult = try await parseCommand("debug-window-events").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(disableResult.exitCode, 0)
        XCTAssertTrue((disableResult.stdout.first ?? "").contains("OFF for com.mitchellh.ghostty"))
    }
}
