import AppKit
import Common

enum FrozenTreeNode: Sendable {
    case container(FrozenContainer)
    case window(FrozenWindow)
}

struct FrozenContainer: Sendable {
    let children: [FrozenTreeNode]
    let orientation: Orientation
    let weight: CGFloat

    @MainActor init(_ container: Column) {
        children = container.children.map {
            if let window = $0 as? Window {
                return .window(FrozenWindow(window))
            }
            if let nestedContainer = $0 as? Column {
                return .container(FrozenContainer(nestedContainer))
            }
            illegalChildParentRelation(child: $0, parent: container)
        }
        orientation = container.orientation
        weight = getWeightOrNil(container) ?? 1
    }
}

struct FrozenWindow: Sendable {
    let id: UInt32
    let weight: CGFloat

    @MainActor init(_ window: Window) {
        id = window.windowId
        weight = getWeightOrNil(window) ?? 1
    }
}

@MainActor private func getWeightOrNil(_ node: TreeNode) -> CGFloat? {
    ((node.parent as? Column)?.orientation).map { node.getWeight($0) }
}
