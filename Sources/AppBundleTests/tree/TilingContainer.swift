@testable import AppBundle
import AppKit

extension Column {
    @MainActor
    static func newHTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat) -> Column {
        newHTiles(parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }

    @MainActor
    static func newVTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat) -> Column {
        newVTiles(parent: parent, adaptiveWeight: adaptiveWeight, index: INDEX_BIND_LAST)
    }
}
