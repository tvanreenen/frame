import AppKit
import Common
import FrameEngine
import FrameUI
import Foundation

func interceptTermination(_ _signal: Int32) {
    signal(_signal, { signal in
        check(Thread.current.isMainThread)
        Task {
            defer { exit(signal) }
            try await terminationHandler.beforeTermination()
        }
    } as sig_t)
}

@MainActor
func initTerminationHandler() {
    terminationHandler = AppServerTerminationHandler()
}

private struct AppServerTerminationHandler: TerminationHandler {
    func beforeTermination() async throws {
        try await makeAllWindowsVisibleAndRestoreSize()
    }
}

@MainActor
private func makeAllWindowsVisibleAndRestoreSize() async throws {
    for (_, window) in Window.allWindowsMap {
        let monitor = try await window.getCenter()?.monitorApproximation ?? mainMonitor
        let monitorVisibleRect = monitor.visibleRect
        let windowSize = window.lastFloatingSize ?? CGSize(width: monitorVisibleRect.width, height: monitorVisibleRect.height)
        let point = CGPoint(
            x: (monitorVisibleRect.width - windowSize.width) / 2,
            y: (monitorVisibleRect.height - windowSize.height) / 2,
        )
        try await window.setAxFrameBlocking(point, windowSize)
    }
}

@MainActor
func terminateApp() {
    NSApplication.shared.terminate(nil)
}

@MainActor
public func menuBarMetadata() -> MenuBarMetadata {
    MenuBarMetadata(
        repositoryUrl: repositoryUrl,
        version: appVersionForDisplay,
        configPath: runtimeContext.configUrl.path,
    )
}

@MainActor
public func quitFromMenuBar() async throws {
    defer { terminateApp() }
    try await terminationHandler.beforeTermination()
}
