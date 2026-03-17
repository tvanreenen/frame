import AppKit
import FrameEngine

var isLeftMouseButtonDown: Bool { NSEvent.pressedMouseButtons == 1 }

@MainActor
func isManipulatedWithMouse(_ window: Window) async throws -> Bool {
    try await (!window.isHiddenInCorner && // Don't allow to resize/move windows of hidden workspaces
        isLeftMouseButtonDown &&
        (currentSession.currentlyManipulatedWithMouseWindowId == nil ||
            window.windowId == currentSession.currentlyManipulatedWithMouseWindowId))
        .andAsync { @Sendable @MainActor in
            guard let nativeFocused = try await getNativeFocusedWindow() else { return false }
            return nativeFocused.app.pid == window.app.pid && nativeFocused.platformWindowId == window.platformWindowId
        }
}
