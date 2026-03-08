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
        for target in ["FrameEngine", "FrameMacOS", "FrameUI"] {
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

    func testFrameMacOSConfiguresPlatformServicesPerSession() throws {
        let hooksFile = projectRoot.appending(path: "Sources/FrameMacOS/PlatformHooks.swift")
        let initFile = projectRoot.appending(path: "Sources/FrameMacOS/initFrameAppRuntime.swift")
        let hooksContent = try String(contentsOf: hooksFile)
        let initContent = try String(contentsOf: initFile)

        XCTAssertTrue(hooksContent.contains("func configureFrameMacOSPlatformServices(for session: AppSession)"))
        XCTAssertTrue(hooksContent.contains("session.platformServices = PlatformServices("))
        XCTAssertFalse(hooksContent.contains("installFrameMacOSHooks"))
        XCTAssertTrue(initContent.contains("configureFrameMacOSPlatformServices(for: session)"))
    }

    func testFrameEngineNoLongerDefinesPlatformHookGlobals() throws {
        let hooksFile = projectRoot.appending(path: "Sources/FrameEngine/PlatformHooks.swift")
        let hooksContent = try String(contentsOf: hooksFile)

        XCTAssertFalse(hooksContent.contains("nativeFocusedWindowProvider"))
        XCTAssertFalse(hooksContent.contains("refreshPlatformAppsProvider"))
        XCTAssertFalse(hooksContent.contains("uiStateSyncHook"))
        XCTAssertFalse(hooksContent.contains("package var mouseLocation: CGPoint"))
        XCTAssertFalse(hooksContent.contains("package var currentlyManipulatedWithMouseWindowId"))
    }

    func testFrameEngineNoLongerOwnsMacosContainerOrWindowLevelTypes() throws {
        let unconventionalFile = projectRoot.appending(path: "Sources/FrameEngine/tree/UnconventionalWindowsContainer.swift")
        let abstractAppFile = projectRoot.appending(path: "Sources/FrameEngine/tree/AbstractApp.swift")
        let macosWindowLevelFile = projectRoot.appending(path: "Sources/FrameMacOS/model/WindowLevelCache.swift")
        let unconventionalContent = try String(contentsOf: unconventionalFile)
        let abstractAppContent = try String(contentsOf: abstractAppFile)
        let macosWindowLevelContent = try String(contentsOf: macosWindowLevelFile)

        XCTAssertFalse(unconventionalContent.contains("MacosFullscreenWindowsContainer"))
        XCTAssertFalse(unconventionalContent.contains("MacosHiddenAppsWindowsContainer"))
        XCTAssertFalse(unconventionalContent.contains("MacosMinimizedWindowsContainer"))
        XCTAssertFalse(unconventionalContent.contains("MacosPopupWindowsContainer"))
        XCTAssertFalse(abstractAppContent.contains("MacOsWindowLevel"))
        XCTAssertTrue(macosWindowLevelContent.contains("package enum MacOsWindowLevel"))
        XCTAssertTrue(macosWindowLevelContent.contains("func getWindowLevel(for windowId: UInt32)"))
    }

    func testEngineAppProtocolUsesDomainWindowOperations() throws {
        let abstractAppFile = projectRoot.appending(path: "Sources/FrameEngine/tree/AbstractApp.swift")
        let windowFile = projectRoot.appending(path: "Sources/FrameEngine/tree/Window.swift")
        let abstractAppContent = try String(contentsOf: abstractAppFile)
        let windowContent = try String(contentsOf: windowFile)

        XCTAssertTrue(abstractAppContent.contains("func getWindowRect(windowId: UInt32)"))
        XCTAssertTrue(abstractAppContent.contains("func setWindowFrame(windowId: UInt32, topLeft: CGPoint?, size: CGSize?)"))
        XCTAssertTrue(abstractAppContent.contains("func getWindowType(windowId: UInt32)"))
        XCTAssertFalse(abstractAppContent.contains("func getAxRect(windowId: UInt32)"))
        XCTAssertFalse(abstractAppContent.contains("func setAxFrame(windowId: UInt32, topLeft: CGPoint?, size: CGSize?)"))
        XCTAssertFalse(abstractAppContent.contains("func getAxUiElementWindowType(windowId: UInt32)"))
        XCTAssertTrue(windowContent.contains("package func getRect() async throws -> Rect?"))
        XCTAssertTrue(windowContent.contains("package func setFrame(_ topLeft: CGPoint?, _ size: CGSize?)"))
        XCTAssertTrue(windowContent.contains("package func getResolvedWindowType() async throws -> AxUiElementWindowType"))
        XCTAssertFalse(windowContent.contains("package func getAxRect() async throws -> Rect?"))
        XCTAssertFalse(windowContent.contains("package func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?)"))
        XCTAssertFalse(windowContent.contains("package func getResolvedAxUiElementWindowType()"))
    }

    func testFrameEngineNoLongerImportsAppKit() throws {
        let root = projectRoot.appending(path: "Sources/FrameEngine")
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var offenders: [String] = []
        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            let content = try String(contentsOf: file)
            if content.contains("import AppKit") {
                offenders.append(file.path)
            }
        }
        assertEquals(offenders.sorted(), [])
    }

    func testConfigModelNoLongerUsesAppKitModifierFlags() throws {
        let configModelFile = projectRoot.appending(path: "Sources/FrameEngine/ConfigModel.swift")
        let configModelContent = try String(contentsOf: configModelFile)

        XCTAssertFalse(configModelContent.contains("NSEvent.ModifierFlags"))
        XCTAssertTrue(configModelContent.contains("struct KeyModifiers"))
        XCTAssertTrue(configModelContent.contains("struct HotkeyBinding"))
    }

    func testFrameMacOSOwnsScreenDiscovery() throws {
        let engineMonitorFile = projectRoot.appending(path: "Sources/FrameEngine/model/Monitor.swift")
        let macosMonitorFile = projectRoot.appending(path: "Sources/FrameMacOS/model/PlatformMonitor.swift")
        let engineMonitorContent = try String(contentsOf: engineMonitorFile)
        let macosMonitorContent = try String(contentsOf: macosMonitorFile)

        XCTAssertFalse(engineMonitorContent.contains("NSScreen"))
        XCTAssertFalse(engineMonitorContent.contains("monitorAppKitNsScreenScreensId"))
        XCTAssertTrue(engineMonitorContent.contains("var systemMonitorIndex: Int"))
        XCTAssertTrue(macosMonitorContent.contains("import AppKit"))
        XCTAssertTrue(macosMonitorContent.contains("NSScreen"))
        XCTAssertTrue(macosMonitorContent.contains("func mainMonitor() -> any Monitor"))
        XCTAssertTrue(macosMonitorContent.contains("func monitors() -> [any Monitor]"))
    }

    func testEnginePlatformSeamIsSessionOwned() throws {
        let engineHooksFile = projectRoot.appending(path: "Sources/FrameEngine/PlatformHooks.swift")
        let sessionFile = projectRoot.appending(path: "Sources/FrameEngine/AppSession.swift")
        let macosHooksFile = projectRoot.appending(path: "Sources/FrameMacOS/PlatformHooks.swift")
        let refreshFile = projectRoot.appending(path: "Sources/FrameEngine/layout/refresh.swift")
        let engineHooksContent = try String(contentsOf: engineHooksFile)
        let sessionContent = try String(contentsOf: sessionFile)
        let macosHooksContent = try String(contentsOf: macosHooksFile)
        let refreshContent = try String(contentsOf: refreshFile)

        XCTAssertTrue(engineHooksContent.contains("struct PlatformServices"))
        XCTAssertTrue(sessionContent.contains("package var platformServices: PlatformServices"))
        XCTAssertTrue(macosHooksContent.contains("session.platformServices = PlatformServices("))
        XCTAssertTrue(refreshContent.contains("platformServices.syncUiState(self)"))
    }

    func testRuntimeCodeUsesSessionUiBoundary() throws {
        let refreshFile = projectRoot.appending(path: "Sources/FrameEngine/layout/refresh.swift")
        let reloadConfigFile = projectRoot.appending(path: "Sources/FrameMacOS/command/impl/ReloadConfigCommand.swift")
        let sessionUiFile = projectRoot.appending(path: "Sources/FrameMacOS/AppSessionUi.swift")
        let refreshContent = try String(contentsOf: refreshFile)
        let reloadConfigContent = try String(contentsOf: reloadConfigFile)
        let sessionUiContent = try String(contentsOf: sessionUiFile)

        XCTAssertTrue(refreshContent.contains("platformServices.syncUiState(self)"))
        XCTAssertFalse(refreshContent.contains("SecureInputPanel.shared.refresh()"))
        XCTAssertFalse(refreshContent.contains("updateTrayText()"))
        XCTAssertTrue(sessionUiContent.contains("func syncUiState()"))
        XCTAssertTrue(sessionUiContent.contains("SecureInputPanel.shared.refresh()"))
        XCTAssertTrue(sessionUiContent.contains("TrayMenuModel.shared.trayText"))
        XCTAssertTrue(reloadConfigContent.contains("session.clearConfigMessage()"))
        XCTAssertTrue(reloadConfigContent.contains("session.setConfigMessage("))
        XCTAssertFalse(reloadConfigContent.contains("MessageModel.shared.message"))
    }

    func testRefreshUsesSessionPlatformServices() async throws {
        let previousSession = currentSession
        let isolatedSession = AppSession(config: defaultConfig, configUrl: defaultConfigUrl)
        var receivedFrontmostBundleId: String?
        var syncUiStateCalls = 0

        isolatedSession.platformServices.frontmostAppBundleId = { "dev.frame.test-app" }
        isolatedSession.platformServices.refreshPlatformApps = { frontmostAppBundleId in
            receivedFrontmostBundleId = frontmostAppBundleId
            return []
        }
        isolatedSession.platformServices.syncUiState = { _ in
            syncUiStateCalls += 1
        }

        currentSession = isolatedSession
        defer { currentSession = previousSession }

        try await isolatedSession.runRefreshSessionBlocking(.menuBarButton, layoutWorkspaces: false)

        assertEquals(receivedFrontmostBundleId, "dev.frame.test-app")
        assertEquals(syncUiStateCalls, 1)
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

    func testCurrentSessionOwnsPlatformSeamState() {
        let previousSession = currentSession
        let isolatedSession = AppSession(config: defaultConfig, configUrl: defaultConfigUrl)
        let point = CGPoint(x: 44, y: 55)
        isolatedSession.platformServices.mouseLocation = { point }
        isolatedSession.currentlyManipulatedWithMouseWindowId = 999

        currentSession = isolatedSession
        defer { currentSession = previousSession }

        assertEquals(currentSession.platformServices.mouseLocation(), point)
        assertEquals(currentSession.currentlyManipulatedWithMouseWindowId, 999)
    }

    func testRefreshNoLongerReadsNSWorkspaceDirectly() throws {
        let refreshFile = projectRoot.appending(path: "Sources/FrameEngine/layout/refresh.swift")
        let refreshContent = try String(contentsOf: refreshFile)

        XCTAssertFalse(refreshContent.contains("NSWorkspace.shared.frontmostApplication"))
        XCTAssertFalse(refreshContent.contains("refreshPlatformAppsProvider("))
        XCTAssertFalse(refreshContent.contains("nativeFocusedWindowProvider()"))
    }

    func testMouseRuntimeCodeUsesSessionPlatformSeam() throws {
        let focusFile = projectRoot.appending(path: "Sources/FrameEngine/focus.swift")
        let layoutFile = projectRoot.appending(path: "Sources/FrameEngine/layout/layoutRecursive.swift")
        let moveMouseFile = projectRoot.appending(path: "Sources/FrameMacOS/mouse/moveWithMouse.swift")
        let resizeMouseFile = projectRoot.appending(path: "Sources/FrameMacOS/mouse/resizeWithMouse.swift")
        let focusContent = try String(contentsOf: focusFile)
        let layoutContent = try String(contentsOf: layoutFile)
        let moveMouseContent = try String(contentsOf: moveMouseFile)
        let resizeMouseContent = try String(contentsOf: resizeMouseFile)

        XCTAssertTrue(focusContent.contains("currentSession.platformServices.mouseLocation()"))
        XCTAssertTrue(focusContent.contains("currentSession.platformServices.followFocusedMonitorWithMouse("))
        XCTAssertTrue(layoutContent.contains("currentSession.currentlyManipulatedWithMouseWindowId"))
        XCTAssertTrue(moveMouseContent.contains("currentSession.platformServices.mouseLocation()"))
        XCTAssertTrue(moveMouseContent.contains("currentSession.currentlyManipulatedWithMouseWindowId"))
        XCTAssertTrue(resizeMouseContent.contains("currentSession.currentlyManipulatedWithMouseWindowId"))
        XCTAssertFalse(focusContent.contains("rect.contains(mouseLocation)"))
        XCTAssertFalse(layoutContent.contains("window.windowId != currentlyManipulatedWithMouseWindowId"))
        XCTAssertFalse(focusContent.contains("CGEvent("))
        XCTAssertFalse(focusContent.contains(".post(tap:"))
    }

    func testRefreshObserverCallbackLivesInFrameMacOS() throws {
        let engineRefreshFile = projectRoot.appending(path: "Sources/FrameEngine/layout/refresh.swift")
        let macosRefreshObserverFile = projectRoot.appending(path: "Sources/FrameMacOS/RefreshObserver.swift")
        let engineRefreshContent = try String(contentsOf: engineRefreshFile)
        let macosRefreshObserverContent = try String(contentsOf: macosRefreshObserverFile)

        XCTAssertFalse(engineRefreshContent.contains("func refreshObs("))
        XCTAssertTrue(macosRefreshObserverContent.contains("func refreshObs("))
        XCTAssertTrue(macosRefreshObserverContent.contains("scheduleRefreshSession(.ax(notif))"))
    }

    func testNativeFocusRunsThroughSessionPlatformServices() throws {
        let windowFile = projectRoot.appending(path: "Sources/FrameEngine/tree/Window.swift")
        let hooksFile = projectRoot.appending(path: "Sources/FrameEngine/PlatformHooks.swift")
        let macosHooksFile = projectRoot.appending(path: "Sources/FrameMacOS/PlatformHooks.swift")
        let abstractAppFile = projectRoot.appending(path: "Sources/FrameEngine/tree/AbstractApp.swift")
        let windowContent = try String(contentsOf: windowFile)
        let hooksContent = try String(contentsOf: hooksFile)
        let macosHooksContent = try String(contentsOf: macosHooksFile)
        let abstractAppContent = try String(contentsOf: abstractAppFile)

        XCTAssertTrue(windowContent.contains("currentSession.platformServices.nativeFocusWindow(app, windowId)"))
        XCTAssertTrue(hooksContent.contains("package var nativeFocusWindow:"))
        XCTAssertTrue(macosHooksContent.contains("nativeFocusWindow: { app, windowId in"))
        XCTAssertFalse(abstractAppContent.contains("func nativeFocus(windowId: UInt32)"))
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

    func testStubPlatformServicesObserveNativeFocusAndFollowMouseRequests() {
        let previousSession = currentSession
        let isolatedSession = AppSession(config: defaultConfig, configUrl: defaultConfigUrl)
        var followedPoint: CGPoint?
        var focusedWindowId: UInt32?

        isolatedSession.platformServices.mouseLocation = { CGPoint(x: -100, y: -100) }
        isolatedSession.platformServices.followFocusedMonitorWithMouse = { target in
            followedPoint = target
        }
        isolatedSession.platformServices.nativeFocusWindow = { _, windowId in
            focusedWindowId = windowId
        }

        currentSession = isolatedSession
        defer { currentSession = previousSession }

        let workspace = Workspace.get(byName: name)
        let window = TestWindow.new(id: 790, parent: workspace.columnsRoot)

        isolatedSession.focusState = FrozenFocus(windowId: nil, workspaceName: workspace.name, monitorId: 0)
        isolatedSession.lastKnownFocus = FrozenFocus(windowId: nil, workspaceName: workspace.name, monitorId: 1)

        isolatedSession.checkFocusCallbacks()
        window.nativeFocus()

        assertEquals(followedPoint, workspace.workspaceMonitor.rect.center)
        assertEquals(focusedWindowId, window.windowId)
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
        let popup = TestWindow.new(id: 779, parent: popupWindowsContainer)
        TestApp.shared.setWindowType(windowId: 779, .window)

        XCTAssertTrue(popup.parent is PopupWindowsContainer)
        try await normalizeLayoutReason()
        XCTAssertFalse(popup.parent is PopupWindowsContainer)
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
        let before = try await window.getRect()

        try await window.hideInCorner(.bottomRightCorner)
        XCTAssertTrue(window.isHiddenInCorner)
        window.unhideFromCorner()
        XCTAssertFalse(window.isHiddenInCorner)

        let after = try await window.getRect()
        assertEquals(after?.size, before?.size)
        assertEquals(after?.topLeftCorner, before?.topLeftCorner)
    }
}
