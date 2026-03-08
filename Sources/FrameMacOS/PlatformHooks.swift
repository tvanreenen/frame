import FrameEngine

@MainActor
private let _frameMacOSHooksInstalled: Void = {
    nativeFocusedWindowProvider = {
        try await getNativeFocusedWindow()
    }
    refreshPlatformAppsProvider = { frontmostAppBundleId in
        try await currentSession.refreshAllMacAppsAndGetAliveWindowIds(frontmostAppBundleId: frontmostAppBundleId)
            .map { ($0.key as any WindowPlatformApp, $0.value) }
    }
    uiStateSyncHook = { @MainActor session in
        session.syncUiState()
    }
}()

@MainActor
func installFrameMacOSHooks() {
    _ = _frameMacOSHooksInstalled
}
