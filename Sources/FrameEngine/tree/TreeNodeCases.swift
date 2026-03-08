import Common

package typealias NonLeafTreeNodeObject = NonLeafTreeNode

package enum ChildParentRelation: Equatable {
    case floatingWindow
    case nativeFullscreenWindow
    case hiddenAppWindow
    case nativeMinimizedWindow
    case popupWindow
    case tiling(parent: Column)
    case rootTilingContainer
    case shimContainerRelation
}

package func getChildParentRelation(child: TreeNode, parent: NonLeafTreeNodeObject) -> ChildParentRelation {
    if let relation = getChildParentRelationOrNil(child: child, parent: parent) {
        return relation
    }
    illegalChildParentRelation(child: child, parent: parent)
}

package func illegalChildParentRelation(child: TreeNode, parent: NonLeafTreeNodeObject?) -> Never {
    die("Illegal child-parent relation. Child: \(child), Parent: \((parent ?? child.parent).prettyDescription)")
}

package func getChildParentRelationOrNil(child: TreeNode, parent: NonLeafTreeNodeObject) -> ChildParentRelation? {
    switch child {
        case is Workspace:
            return nil
        case is Window:
            switch parent {
                case let container as Column:
                    return .tiling(parent: container)
                case is Workspace:
                    return .floatingWindow
                case is PopupWindowsContainer:
                    return .popupWindow
                case is NativeMinimizedWindowsContainer:
                    return .nativeMinimizedWindow
                case is NativeFullscreenWindowsContainer:
                    return .nativeFullscreenWindow
                case is HiddenAppWindowsContainer:
                    return .hiddenAppWindow
                default:
                    die("Unknown tree \(parent)")
            }
        case is Column:
            switch parent {
                case let container as Column:
                    return .tiling(parent: container)
                case is Workspace:
                    return .rootTilingContainer
                case is PopupWindowsContainer,
                     is NativeMinimizedWindowsContainer,
                     is NativeFullscreenWindowsContainer,
                     is HiddenAppWindowsContainer:
                    return nil
                default:
                    die("Unknown tree \(parent)")
            }
        case is NativeFullscreenWindowsContainer, is HiddenAppWindowsContainer:
            switch parent {
                case is Workspace:
                    return .shimContainerRelation
                default:
                    return nil
            }
        case is NativeMinimizedWindowsContainer, is PopupWindowsContainer:
            return nil
        default:
            die("Unknown tree \(child)")
    }
}
