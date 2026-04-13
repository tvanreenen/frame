import AppKit
import Common
import FrameEngine

private struct PlatformMonitor: Monitor {
    let systemMonitorIndex: Int
    let name: String
    let rect: Rect
    let visibleRect: Rect
    let isMain: Bool

    var height: CGFloat { rect.height }
    var width: CGFloat { rect.width }
}

private final class LazyMonitor: Monitor {
    private let screen: NSScreen
    private let mainMonitorHeight: CGFloat
    let systemMonitorIndex: Int
    let name: String
    let width: CGFloat
    let height: CGFloat
    let isMain: Bool
    private var _rect: Rect?
    private var _visibleRect: Rect?

    init(systemMonitorIndex: Int, isMain: Bool, mainMonitorHeight: CGFloat, _ screen: NSScreen) {
        self.mainMonitorHeight = mainMonitorHeight
        self.systemMonitorIndex = systemMonitorIndex
        self.name = screen.localizedName
        self.width = screen.frame.width // Don't call rect because it would cause recursion during mainMonitor init
        self.height = screen.frame.height // Don't call rect because it would cause recursion during mainMonitor init
        self.screen = screen
        self.isMain = isMain
    }

    var rect: Rect {
        _rect ?? screen.frame.platformMonitorFrameNormalized(mainMonitorHeight: mainMonitorHeight).also { _rect = $0 }
    }

    var visibleRect: Rect {
        _visibleRect ?? screen.visibleFrame.platformMonitorFrameNormalized(mainMonitorHeight: mainMonitorHeight).also { _visibleRect = $0 }
    }
}

// Note to myself: Don't use NSScreen.main, it's garbage
// 1. The name is misleading, it's supposed to be called "focusedScreen"
// 2. It's inaccurate because NSScreen.main doesn't work correctly from NSWorkspace.didActivateApplicationNotification &
//    kAXFocusedWindowChangedNotification callbacks.
extension NSScreen {
    fileprivate func toMonitor(systemMonitorIndex: Int, mainMonitorHeight: CGFloat) -> any Monitor {
        PlatformMonitor(
            systemMonitorIndex: systemMonitorIndex,
            name: localizedName,
            rect: frame.platformMonitorFrameNormalized(mainMonitorHeight: mainMonitorHeight),
            visibleRect: visibleFrame.platformMonitorFrameNormalized(mainMonitorHeight: mainMonitorHeight),
            isMain: isMainScreen,
        )
    }

    fileprivate var isMainScreen: Bool {
        frame.minX == 0 && frame.minY == 0
    }
}

@MainActor
package func mainMonitor() -> any Monitor {
    if isUnitTest { return defaultTestMonitor }
    let screens = NSScreen.screens
    let mainMonitorHeight = screens.withIndex.first(where: { $0.value.isMainScreen })?.value.frame.maxY
        ?? screens.first?.frame.maxY
        ?? defaultTestMonitor.height
    // Fallback: If main screen can't be found (e.g., during display reconfiguration),
    // return screens.first or defaultTestMonitor to avoid crash
    let screen = screens.withIndex.first(where: { $0.value.isMainScreen }) ?? screens.first.map { (0, $0) }
    guard let screen else { return defaultTestMonitor }
    return LazyMonitor(systemMonitorIndex: screen.index + 1, isMain: true, mainMonitorHeight: mainMonitorHeight, screen.value)
}

@MainActor
package func monitors() -> [any Monitor] {
    let screens = NSScreen.screens
    let mainMonitorHeight = screens.withIndex.first(where: { $0.value.isMainScreen })?.value.frame.maxY
        ?? screens.first?.frame.maxY
        ?? defaultTestMonitor.height
    return isUnitTest
        ? [defaultTestMonitor]
        : screens.enumerated().map { $0.element.toMonitor(systemMonitorIndex: $0.offset + 1, mainMonitorHeight: mainMonitorHeight) }
}

extension CGRect {
    fileprivate func platformMonitorFrameNormalized(mainMonitorHeight: CGFloat) -> Rect {
        let rect = toRect()
        return rect.copy(\.topLeftY, mainMonitorHeight - rect.topLeftY)
    }
}
