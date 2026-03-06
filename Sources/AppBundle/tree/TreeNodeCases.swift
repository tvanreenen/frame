import Common

protocol NonLeafTreeNodeObject: TreeNode {}

enum ChildParentRelation: Equatable {
    case floatingWindow
    case macosNativeFullscreenWindow
    case macosNativeHiddenAppWindow
    case macosNativeMinimizedWindow
    case macosPopupWindow
    case tiling(parent: Column)
    case rootTilingContainer
    case shimContainerRelation
}

func getChildParentRelation(child: TreeNode, parent: NonLeafTreeNodeObject) -> ChildParentRelation {
    if let relation = getChildParentRelationOrNil(child: child, parent: parent) {
        return relation
    }
    illegalChildParentRelation(child: child, parent: parent)
}

func illegalChildParentRelation(child: TreeNode, parent: NonLeafTreeNodeObject?) -> Never {
    die("Illegal child-parent relation. Child: \(child), Parent: \((parent ?? child.parent).prettyDescription)")
}

func getChildParentRelationOrNil(child: TreeNode, parent: NonLeafTreeNodeObject) -> ChildParentRelation? {
    switch child {
        case is Workspace:
            return nil
        case is Window:
            switch parent {
                case let container as Column:
                    return .tiling(parent: container)
                case is Workspace:
                    return .floatingWindow
                case is MacosPopupWindowsContainer:
                    return .macosPopupWindow
                case is MacosMinimizedWindowsContainer:
                    return .macosNativeMinimizedWindow
                case is MacosFullscreenWindowsContainer:
                    return .macosNativeFullscreenWindow
                case is MacosHiddenAppsWindowsContainer:
                    return .macosNativeHiddenAppWindow
                default:
                    die("Unknown tree \(parent)")
            }
        case is Column:
            switch parent {
                case let container as Column:
                    return .tiling(parent: container)
                case is Workspace:
                    return .rootTilingContainer
                case is MacosPopupWindowsContainer,
                     is MacosMinimizedWindowsContainer,
                     is MacosFullscreenWindowsContainer,
                     is MacosHiddenAppsWindowsContainer:
                    return nil
                default:
                    die("Unknown tree \(parent)")
            }
        case is MacosFullscreenWindowsContainer, is MacosHiddenAppsWindowsContainer:
            switch parent {
                case is Workspace:
                    return .shimContainerRelation
                default:
                    return nil
            }
        case is MacosMinimizedWindowsContainer, is MacosPopupWindowsContainer:
            return nil
        default:
            die("Unknown tree \(child)")
    }
}
