@testable import AppBundle
import Foundation
import XCTest

@MainActor
final class WindowArchitectureTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testNoMacWindowSpecificCastsRemain() throws {
        let root = projectRoot.appending(path: "Sources/AppBundle")
        var offenders: [String] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            let content = try String(contentsOf: file)
            if content.contains("as! MacWindow") || content.contains("asMacWindow(") {
                offenders.append(file.path)
            }
        }
        assertEquals(offenders.sorted(), [])
    }

    func testWindowHasNoNotImplementedStubs() throws {
        let file = projectRoot.appending(path: "Sources/AppBundle/tree/Window.swift")
        let content = try String(contentsOf: file)
        XCTAssertFalse(content.contains("die(\"Not implemented\")"))
    }

    func testWindowRegistryLookupWorks() {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 777, parent: workspace.rootTilingContainer)
        assertEquals(Window.get(byId: 777), window)
    }

    func testRelayoutWindowFromFloatingStillWorks() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(
            id: 778,
            parent: workspace,
            rect: Rect(topLeftX: 5, topLeftY: 5, width: 100, height: 100),
        )

        XCTAssertTrue(window.parent is Workspace)
        try await window.relayoutWindow(on: workspace)
        XCTAssertTrue(window.parent is Column)
    }

    func testPopupNormalizationPathWithoutMacWindowCast() async throws {
        let popup = TestWindow.new(id: 779, parent: macosPopupWindowsContainer)
        TestApp.shared.setWindowHeuristic(windowId: 779, true)
        TestApp.shared.setWindowType(windowId: 779, .window)

        XCTAssertTrue(popup.parent is MacosPopupWindowsContainer)
        try await normalizeLayoutReason()
        XCTAssertFalse(popup.parent is MacosPopupWindowsContainer)
    }

    func testHideUnhideCornerRoundTrip() async throws {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(
            id: 780,
            parent: workspace,
            rect: Rect(topLeftX: 120, topLeftY: 90, width: 500, height: 350),
        )
        let before = try await window.getAxRect()

        try await window.hideInCorner(.bottomRightCorner)
        XCTAssertTrue(window.isHiddenInCorner)
        window.unhideFromCorner()
        XCTAssertFalse(window.isHiddenInCorner)

        let after = try await window.getAxRect()
        assertEquals(after?.size, before?.size)
        assertEquals(after?.topLeftCorner, before?.topLeftCorner)
    }
}
