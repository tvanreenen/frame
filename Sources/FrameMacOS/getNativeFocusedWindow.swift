import AppKit
import Common
import FrameEngine

@MainActor
var appForTests: (any AbstractApp)? = nil

@MainActor
private func focusedApp() async throws -> (any AbstractApp)? {
    if isUnitTest {
        return appForTests
    } else {
        check(appForTests == nil)
        return try await NSWorkspace.shared.frontmostApplication.flatMapAsyncMainActor(currentSession.getOrRegisterMacApp)
    }
}

@MainActor
func getNativeFocusedWindow() async throws -> Window? {
    try await focusedApp()?.getFocusedWindow()
}
