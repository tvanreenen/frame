import Common
import Foundation

private struct TestMonitor: Monitor {
    let systemMonitorIndex: Int
    let name: String
    let rect: Rect
    let visibleRect: Rect
    let isMain: Bool

    var height: CGFloat { rect.height }
    var width: CGFloat { rect.width }
}

/// Use it instead of platform-native screen types because it can be mocked in tests.
package protocol Monitor: AeroAny {
    /// The index in the platform screen list. 1-based index.
    var systemMonitorIndex: Int { get }
    var name: String { get }
    var rect: Rect { get }
    var visibleRect: Rect { get }
    var width: CGFloat { get }
    var height: CGFloat { get }
    var isMain: Bool { get }
}

private let testMonitorRect = Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080)
@MainActor
package var defaultTestMonitor: any Monitor = TestMonitor(
    systemMonitorIndex: 1,
    name: "Test Monitor",
    rect: testMonitorRect,
    visibleRect: testMonitorRect,
    isMain: true,
)

@MainActor
package var mainMonitor: any Monitor {
    currentSession.platformServices.mainMonitor()
}

@MainActor
package var monitors: [any Monitor] {
    currentSession.platformServices.monitors()
}

@MainActor
package var sortedMonitors: [any Monitor] {
    monitors.sortedBy([\.rect.minX, \.rect.minY])
}
