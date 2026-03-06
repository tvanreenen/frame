@testable import AppBundle
import Common
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

    func testMacAppNoLongerOwnsStaticRuntimeRegistries() throws {
        let file = projectRoot.appending(path: "Sources/AppBundle/tree/MacApp.swift")
        let content = try String(contentsOf: file)

        XCTAssertFalse(content.contains("static var allAppsMap"))
        XCTAssertFalse(content.contains("static var wipPids"))
        XCTAssertFalse(content.contains("static func getOrRegister("))
        XCTAssertFalse(content.contains("static func refreshAllAndGetAliveWindowIds("))
    }

    func testWindowHasNoNotImplementedStubs() throws {
        let file = projectRoot.appending(path: "Sources/AppBundle/tree/Window.swift")
        let content = try String(contentsOf: file)
        XCTAssertFalse(content.contains("die(\"Not implemented\")"))
    }

    func testWindowRegistryLookupWorks() {
        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 777, parent: workspace.columnsRoot)
        assertEquals(Window.get(byId: 777), window)
    }

    func testCurrentSessionOwnsRuntimeRegistries() {
        let workspace = Workspace.get(byName: name)
        _ = TestWindow.new(id: 788, parent: workspace.columnsRoot)

        XCTAssertFalse(Workspace.all.isEmpty)
        XCTAssertNotNil(Window.get(byId: 788))

        currentSession = AppSession(config: defaultConfig, configUrl: defaultConfigUrl)

        XCTAssertTrue(Workspace.all.isEmpty)
        XCTAssertNil(Window.get(byId: 788))
        XCTAssertTrue(runtimeContext === currentSession)
    }

    func testRunCmdSeqUsesProvidedSessionAndRestoresCurrentSession() async throws {
        struct SessionProbeCommand: Command {
            typealias T = AddColumnCmdArgs
            let args = AddColumnCmdArgs(rawArgs: [])
            let expectedSession: AppSession
            let previousSession: AppSession

            @MainActor
            func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
                XCTAssertTrue(session === expectedSession)
                XCTAssertTrue(currentSession === expectedSession)
                XCTAssertFalse(currentSession === previousSession)
                return true
            }

            var shouldResetClosedWindowsCache: Bool { false }
        }

        let previousSession = currentSession
        let isolatedSession = AppSession(config: defaultConfig, configUrl: defaultConfigUrl)
        let commands: [any Command] = [SessionProbeCommand(
            expectedSession: isolatedSession,
            previousSession: previousSession,
        )]

        let result = try await commands.runCmdSeq(in: isolatedSession, .defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(currentSession === previousSession)
        XCTAssertFalse(currentSession === isolatedSession)
    }

    func testSessionCallbackContextRoundTrips() {
        let session = AppSession(config: defaultConfig, configUrl: defaultConfigUrl)

        XCTAssertTrue(AppSession.fromCallbackContext(session.callbackContext) === session)
        XCTAssertNil(AppSession.fromCallbackContext(nil as AppSessionCallbackContext?))
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

    func testRelayoutWindowUsesFocusedColumnForNewTilingPlacement() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 782, parent: col1)
        _ = TestWindow.new(id: 783, parent: col2).focusWindow()
        let window = TestWindow.new(
            id: 784,
            parent: workspace,
            rect: Rect(topLeftX: 5, topLeftY: 5, width: 100, height: 100),
        )

        try await window.relayoutWindow(on: workspace)

        XCTAssertTrue(window.parent === col2)
    }

    func testPopupNormalizationPathWithoutMacWindowCast() async throws {
        let popup = TestWindow.new(id: 779, parent: macosPopupWindowsContainer)
        TestApp.shared.setWindowType(windowId: 779, .window)

        XCTAssertTrue(popup.parent is MacosPopupWindowsContainer)
        try await normalizeLayoutReason()
        XCTAssertFalse(popup.parent is MacosPopupWindowsContainer)
    }

    func testWindowClassificationOverrideAppliedOnRegistration() async throws {
        runtimeContext.config.windowClassificationOverrides = [
            WindowClassificationOverride(
                matcher: WindowClassificationOverrideMatcher(
                    appId: TestApp.shared.rawAppBundleId,
                    appNameRegexSubstring: nil,
                    windowTitleRegexSubstring: nil,
                ),
                kind: .window,
            ),
        ]
        TestApp.shared.setWindowType(windowId: 781, .popup)

        let window = try await Window.getOrRegister(windowId: 781, app: TestApp.shared)
        XCTAssertTrue(window.parent is Column)
    }

    func testWindowRegistrationUsesFocusedColumnForNewTilingPlacement() async throws {
        let workspace = Workspace.get(byName: name)
        let col1 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        let col2 = Column.newVTiles(parent: workspace.columnsRoot, adaptiveWeight: 1)
        _ = TestWindow.new(id: 785, parent: col1)
        _ = TestWindow.new(id: 786, parent: col2).focusWindow()

        let window = try await Window.getOrRegister(windowId: 787, app: TestApp.shared)

        XCTAssertTrue(window.parent === col2)
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
