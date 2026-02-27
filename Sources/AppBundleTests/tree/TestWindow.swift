@testable import AppBundle
import AppKit

enum TestWindow {
    @discardableResult
    @MainActor
    static func new(id: UInt32, parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat = 1, rect: Rect? = nil) -> Window {
        TestApp.shared.registerWindow(id: id, parent: parent, adaptiveWeight: adaptiveWeight, rect: rect)
    }
}
