import AppKit
import Common
import FrameEngine

@MainActor
package var appForTests: (any AbstractApp)? = nil

@MainActor
private func focusedApp(session: AppSession) async throws -> (any AbstractApp)? {
    if isUnitTest {
        return appForTests
    } else {
        check(appForTests == nil)
        return try await NSWorkspace.shared.frontmostApplication.flatMapAsyncMainActor(session.getOrRegisterMacApp)
    }
}

@MainActor
func getNativeFocusedWindow(session: AppSession = currentSession) async throws -> Window? {
    try await focusedApp(session: session)?.getFocusedWindow()
}
