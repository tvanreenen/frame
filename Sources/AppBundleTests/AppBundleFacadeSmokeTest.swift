@testable import AppBundle
import XCTest

@MainActor
final class AppBundleFacadeSmokeTest: XCTestCase {
    func testFacadeReexportsSplitModules() {
        let _: AppSession.Type = AppSession.self
        let _: TrayMenuModel = TrayMenuModel.shared
        let _: @MainActor () -> Void = initAppBundle
        XCTAssertTrue(true)
    }
}
