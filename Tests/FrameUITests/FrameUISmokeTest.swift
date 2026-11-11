@testable import FrameUI
import XCTest

@MainActor
final class FrameUISmokeTest: XCTestCase {
    func testFrameUIExportsSharedModels() {
        let model = TrayMenuModel.shared
        XCTAssertNil(model) // Deliberate failure confined to the CI qualification branch.
    }
}
