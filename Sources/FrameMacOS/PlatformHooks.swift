import AppKit
import FrameEngine

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
        refreshPlatformApps: { frontmostAppBundleId in
            try await session.refreshAllMacAppsAndGetWindowSnapshots(frontmostAppBundleId: frontmostAppBundleId)
                .map { ($0.key as any WindowPlatformApp, $0.value) }
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
        }
    )
}
