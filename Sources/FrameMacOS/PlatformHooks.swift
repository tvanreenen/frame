import AppKit
import FrameEngine

package func makePlatformObservationUnavailableReason(
    frontmostAppBundleId: String?,
    isAccessibilityTrusted: Bool,
) -> PlatformObservationUnavailableReason? {
    if frontmostAppBundleId == lockScreenAppBundleId { return .screenLocked }
    if !isAccessibilityTrusted { return .accessibilityUnavailable }
    return nil
}

@MainActor
func configureFrameMacOSPlatformServices(for session: AppSession) {
    session.platformServices = PlatformServices(
        mainMonitor: {
            mainMonitor()
        },
        monitors: {
            monitors()
        },
        nativeFocusedWindow: {
            try await getNativeFocusedWindow(session: session)
        },
        frontmostAppBundleId: {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
        refreshPlatformState: {
            try await session.refreshMacOSPlatformState()
        },
        syncUiState: { session in
            session.syncUiState()
        },
        mouseLocation: {
            let location = NSEvent.mouseLocation
            return CGPoint(x: location.x, y: NSScreen.screens.first!.frame.maxY - location.y)
        },
        followFocusedMonitorWithMouse: { target in
            let event = CGEvent(
                mouseEventSource: nil,
                mouseType: .mouseMoved,
                mouseCursorPosition: target,
                mouseButton: .left,
            )
            event?.post(tap: .cghidEventTap)
        },
        nativeFocusWindow: { app, windowId in
            (app as? MacApp)?.focusWindowNatively(windowId: windowId)
        },
    )
}
