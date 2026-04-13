import FrameEngine
import FrameMacOS
import FrameUI
import AppKit

extension Column {
    @MainActor
    package static func newHTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat) -> Column {
        newHTiles(parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }

    @MainActor
    package static func newVTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat) -> Column {
        newVTiles(parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }
}
