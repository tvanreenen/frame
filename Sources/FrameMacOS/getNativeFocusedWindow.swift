import AppKit
import Common
import FrameEngine

@MainActor
package var appForTests: (any WindowPlatformApp)? = nil

@MainActor
private func focusedApp(session: AppSession) async throws -> (any WindowPlatformApp)? {
    if isUnitTest {
        return appForTests
    } else {
        check(appForTests == nil)
        return try await NSWorkspace.shared.frontmostApplication.flatMapAsyncMainActor(session.getOrRegisterMacApp)
    }
}

@MainActor
func getNativeFocusedWindow(session: AppSession = currentSession) async throws -> NativeFocusedWindowSnapshot? {
    guard let app = try await focusedApp(session: session) else { return nil }
    guard let platformWindowId = try await app.getFocusedPlatformWindowId() else { return nil }
    return NativeFocusedWindowSnapshot(app: app, platformWindowId: platformWindowId)
}
