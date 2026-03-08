import FrameEngine
import FrameMacOS
import FrameUI
import AppKit

package enum TestWindow {
    @discardableResult
    @MainActor
    package static func new(id: UInt32, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat = 1, rect: Rect? = nil) -> Window {
        TestApp.shared.registerWindow(id: id, parent: parent, adaptiveWeight: adaptiveWeight, rect: rect)
    }
}
