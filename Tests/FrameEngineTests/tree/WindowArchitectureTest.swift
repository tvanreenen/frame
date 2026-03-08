@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import Foundation
import XCTest
import FrameTestSupport

@MainActor
final class WindowArchitectureTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testNoMacWindowSpecificCastsRemain() throws {
        var offenders: [String] = []
        for target in ["FrameEngine", "FrameMacOS", "FrameUI", "AppBundle"] {
            let root = projectRoot.appending(path: "Sources/\(target)")
            let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            while let file = enumerator?.nextObject() as? URL {
                guard file.pathExtension == "swift" else { continue }
                let content = try String(contentsOf: file)
                if content.contains("as! MacWindow") || content.contains("asMacWindow(") {
                    offenders.append(file.path)
                }
            }
        }
        assertEquals(offenders.sorted(), [])
    }

    func testMacAppNoLongerOwnsStaticRuntimeRegistries() throws {
        let file = projectRoot.appending(path: "Sources/FrameMacOS/tree/MacApp.swift")
        let content = try String(contentsOf: file)

        XCTAssertFalse(content.contains("static var allAppsMap"))
        XCTAssertFalse(content.contains("static var wipPids"))
        XCTAssertFalse(content.contains("static func getOrRegister("))
        XCTAssertFalse(content.contains("static func refreshAllAndGetAliveWindowIds("))
    }

    func testRuntimeCodeUsesSessionUiBoundary() throws {
        let refreshFile = projectRoot.appending(path: "Sources/FrameEngine/layout/refresh.swift")
        let reloadConfigFile = projectRoot.appending(path: "Sources/FrameMacOS/command/impl/ReloadConfigCommand.swift")
        let sessionUiFile = projectRoot.appending(path: "Sources/FrameMacOS/AppSessionUi.swift")
        let refreshContent = try String(contentsOf: refreshFile)
        let reloadConfigContent = try String(contentsOf: reloadConfigFile)
        let sessionUiContent = try String(contentsOf: sessionUiFile)

        XCTAssertTrue(refreshContent.contains("uiStateSyncHook(self)"))
        XCTAssertFalse(refreshContent.contains("SecureInputPanel.shared.refresh()"))
        XCTAssertFalse(refreshContent.contains("updateTrayText()"))
        XCTAssertTrue(sessionUiContent.contains("func syncUiState()"))
        XCTAssertTrue(sessionUiContent.contains("SecureInputPanel.shared.refresh()"))
        XCTAssertTrue(sessionUiContent.contains("TrayMenuModel.shared.trayText"))
        XCTAssertTrue(reloadConfigContent.contains("session.clearConfigMessage()"))
        XCTAssertTrue(reloadConfigContent.contains("session.setConfigMessage("))
        XCTAssertFalse(reloadConfigContent.contains("MessageModel.shared.message"))
    }

    func testWindowHasNoNotImplementedStubs() throws {
        let file = projectRoot.appending(path: "Sources/FrameEngine/tree/Window.swift")
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
        var matcher = WindowClassificationOverrideMatcher()
        matcher.appId = TestApp.shared.rawAppBundleId
        var override = WindowClassificationOverride()
        override.matcher = matcher
        override.kind = .window
        runtimeContext.config.windowClassificationOverrides = [
            override,
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
