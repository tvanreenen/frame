import Common
import Foundation

struct FrozenColumn: Sendable {
    let windows: [FrozenWindow]
    let weight: CGFloat

    @MainActor init(_ column: Column) {
        windows = column.children.compactMap { $0 as? Window }.map(FrozenWindow.init)
        weight = getWeightOrNil(column) ?? 1
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
