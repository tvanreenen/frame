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

    func testPlatformObservationUnavailableReasonIsNilWhenObservationIsHealthy() {
        let result = makePlatformObservationUnavailableReason(
            frontmostAppBundleId: nil,
            isAccessibilityTrusted: true,
        )

        XCTAssertNil(result)
    }

    func testPlatformObservationUnavailableReasonDetectsScreenLock() {
        let result = makePlatformObservationUnavailableReason(
            frontmostAppBundleId: lockScreenAppBundleId,
            isAccessibilityTrusted: true,
        )

        assertEquals(result, .screenLocked)
    }

    func testPlatformObservationUnavailableReasonDetectsAccessibilityOutage() {
        let result = makePlatformObservationUnavailableReason(
            frontmostAppBundleId: nil,
            isAccessibilityTrusted: false,
        )

        assertEquals(result, .accessibilityUnavailable)
    }
}
