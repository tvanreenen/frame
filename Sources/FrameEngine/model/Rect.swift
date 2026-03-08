import AppKit
import Common

package struct Rect: ConvenienceCopyable, AeroAny {
    package var topLeftX: CGFloat
    package var topLeftY: CGFloat

    private var _width: CGFloat
    package var width: CGFloat {
        get { max(_width, 0) }
        set(newValue) { _width = newValue }
    }

    private var _height: CGFloat
    package var height: CGFloat {
        get { max(_height, 0) }
        set(newValue) { _height = newValue }
    }

    package init(topLeftX: CGFloat, topLeftY: CGFloat, width: CGFloat, height: CGFloat) {
        self.topLeftX = topLeftX
        self.topLeftY = topLeftY
        self._width = width
        self._height = height
    }
}

extension CGRect {
    package func monitorFrameNormalized() -> Rect {
        let mainMonitorHeight: CGFloat = mainMonitor.height
        let rect = toRect()
        return rect.copy(\.topLeftY, mainMonitorHeight - rect.topLeftY)
    }
}

extension CGRect {
    package func toRect() -> Rect {
        Rect(topLeftX: minX, topLeftY: maxY, width: width, height: height)
    }
}

extension Rect {
    package func contains(_ point: CGPoint) -> Bool {
        minX.until(excl: maxX)?.contains(point.x) == true && minY.until(excl: maxY)?.contains(point.y) == true
    }

    package var center: CGPoint {
        CGPoint(x: topLeftX + width / 2, y: topLeftY + height / 2)
    }

    package var topLeftCorner: CGPoint { CGPoint(x: topLeftX, y: topLeftY) }
    package var topRightCorner: CGPoint { CGPoint(x: maxX, y: minY) }
    package var bottomRightCorner: CGPoint { CGPoint(x: maxX, y: maxY) }
    package var bottomLeftCorner: CGPoint { CGPoint(x: minX, y: maxY) }

    package var minY: CGFloat { topLeftY }
    package var maxY: CGFloat { topLeftY + height }
    package var minX: CGFloat { topLeftX }
    package var maxX: CGFloat { topLeftX + width }

    package var size: CGSize { CGSize(width: width, height: height) }

    package func getDimension(_ orientation: Orientation) -> CGFloat { orientation == .h ? width : height }
}
