@testable import FrameEngine
@testable import FrameMacOS
import XCTest
import FrameTestSupport

@MainActor
final class NativeFocusedWindowTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testNativeFocusedWindowSnapshotDoesNotRegisterLogicalWindow() async throws {
        appForTests = TestApp.shared
        TestApp.shared.focusedPlatformWindowId = 999

        let snapshot = try await getNativeFocusedWindow(session: currentSession)

        XCTAssertTrue(snapshot?.app === TestApp.shared)
        assertEquals(snapshot?.platformWindowId, 999)
        assertEquals(Window.allWindows.count, 0)
    }

    func testAuthoritativeTopLevelWindowIdsIgnoreCachedWindows() {
        let result = makeAuthoritativeTopLevelWindowIds(
            axWindowIds: [5085],
            focusedWindowId: 5085,
        )

        assertEquals(result, [5085])
    }

    func testAuthoritativeTopLevelWindowIdsIncludeFocusedWindowOnce() {
        let result = makeAuthoritativeTopLevelWindowIds(
            axWindowIds: [5085],
            focusedWindowId: 5091,
        )

        assertEquals(result, [5085, 5091])
    }
}
