@testable import FrameUI
import XCTest

@MainActor
final class FrameUISmokeTest: XCTestCase {
    func testFrameUIExportsSharedModels() {
        let model = TrayMenuModel.shared
        XCTAssertNotNil(model)
    }
}
