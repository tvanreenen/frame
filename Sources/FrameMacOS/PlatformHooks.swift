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
            try await session.refreshAllMacAppsAndGetAliveWindowIds(frontmostAppBundleId: frontmostAppBundleId)
                .map { ($0.key as any WindowPlatformApp, $0.value) }
        },
        syncUiState: { session in
            session.syncUiState()
        },
        mouseLocation: {
            let location = NSEvent.mouseLocation
            return CGPoint(x: location.x, y: NSScreen.screens.first!.frame.maxY - location.y)
        },
    )
}
