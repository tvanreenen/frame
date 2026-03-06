import AppKit
import Common

final class Column: TreeNode, NonLeafTreeNodeObject {
    fileprivate var _orientation: Orientation
    var orientation: Orientation { _orientation }

    @MainActor
    init(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, _ orientation: Orientation, index: Int) {
        if let workspace = parent as? Workspace {
            check(orientation == .h, "Workspace root tiling container must be horizontal")
            check(workspace.children.filterIsInstance(of: Column.self).isEmpty,
                  "Workspace must contain exactly one root tiling container")
        }
        self._orientation = orientation
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor
    static func newHTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) -> Column {
        Column(parent: parent, adaptiveWeight: adaptiveWeight, .h, index: index)
    }

    @MainActor
    static func newVTiles(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) -> Column {
        Column(parent: parent, adaptiveWeight: adaptiveWeight, .v, index: index)
    }
}

extension Column {
    var isRootContainer: Bool { parent is Workspace }

    func setOrientation(_ orientation: Orientation) {
        guard !isRootContainer else { die("Workspace root tiling container orientation is structural") }
        _orientation = orientation
    }
}
