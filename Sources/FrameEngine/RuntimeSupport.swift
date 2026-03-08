import Common
import CoreGraphics
import Foundation
import os

package let signposter = OSSignposter(subsystem: appBundleId, category: .pointsOfInterest)
package let myPid = ProcessInfo.processInfo.processIdentifier
package let lockScreenAppBundleId = "com.apple.loginwindow"

package func - (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x - b.x, y: a.y - b.y)
}

package func + (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x + b.x, y: a.y + b.y)
}

extension CGPoint: ConvenienceCopyable {}

extension CGPoint {
    package func distanceToRectFrame(to rect: Rect) -> CGFloat {
        let list: [CGFloat] = (rect.minY.until(excl: rect.maxY)?.contains(y) == true ? [abs(rect.minX - x), abs(rect.maxX - x)] : []) +
            (rect.minX.until(excl: rect.maxX)?.contains(x) == true ? [abs(rect.minY - y), abs(rect.maxY - y)] : []) +
            [
                distance(to: rect.topLeftCorner),
                distance(to: rect.bottomRightCorner),
                distance(to: rect.topRightCorner),
                distance(to: rect.bottomLeftCorner),
            ]
        return list.minOrDie()
    }

    package func addingXOffset(_ offset: CGFloat) -> CGPoint { CGPoint(x: x + offset, y: y) }
    package func addingYOffset(_ offset: CGFloat) -> CGPoint { CGPoint(x: x, y: y + offset) }
    package func addingOffset(_ orientation: Orientation, _ offset: CGFloat) -> CGPoint { orientation == .h ? addingXOffset(offset) : addingYOffset(offset) }
    package func getProjection(_ orientation: Orientation) -> Double { orientation == .h ? x : y }
    package var vectorLength: CGFloat { sqrt(x * x + y * y) }

    package func distance(to point: CGPoint) -> Double {
        sqrt((x - point.x).squared + (y - point.y).squared)
    }

    @MainActor
    package var monitorApproximation: Monitor {
        let monitors = monitors
        return monitors.first(where: { $0.rect.contains(self) })
            ?? monitors.minByOrDie { distanceToRectFrame(to: $0.rect) }
    }
}

extension CGFloat {
    package func div(_ denominator: Int) -> CGFloat? {
        denominator == 0 ? nil : self / CGFloat(denominator)
    }

    package func coerceIn(_ range: ClosedRange<CGFloat>) -> CGFloat {
        switch true {
            case self > range.upperBound: range.upperBound
            case self < range.lowerBound: range.lowerBound
            default: self
        }
    }
}

extension CGPoint: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

#if DEBUG
    package let isDebug = true
#else
    package let isDebug = false
#endif

@inlinable
package func checkCancellation() throws(CancellationError) {
    if Task.isCancelled {
        throw CancellationError()
    }
}
