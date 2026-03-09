import Common
import Foundation

extension TreeNode {
    private func visit(node: TreeNode, result: inout [Window]) {
        if let node = node as? Window {
            result.append(node)
        }
        for child in node.children {
            visit(node: child, result: &result)
        }
    }
    package var allLeafWindowsRecursive: [Window] {
        var result: [Window] = []
        visit(node: self, result: &result)
        return result
    }

    package var ownIndex: Int? {
        guard let parent else { return nil }
        return parent.children.firstIndex(of: self).orDie()
    }

    package var parents: [NonLeafTreeNodeObject] { parent.flatMap { [$0] + $0.parents } ?? [] }
    package var parentsWithSelf: [TreeNode] { parent.flatMap { [self] + $0.parentsWithSelf } ?? [self] }

    /// Also see visualWorkspace
    package var nodeWorkspace: Workspace? {
        self as? Workspace ?? parent?.nodeWorkspace
    }

    /// Also see: workspace
    @MainActor
    package var visualWorkspace: Workspace? { nodeWorkspace ?? nodeMonitor?.activeWorkspace }

    @MainActor
    package var nodeMonitor: Monitor? {
        if let workspace = self as? Workspace {
            return workspace.workspaceMonitor
        }
        if self is Window || self is Column || self is NativeFullscreenWindowsContainer || self is HiddenAppWindowsContainer {
            return parent?.nodeMonitor
        }
        if self is NativeMinimizedWindowsContainer || self is ExcludedWindowsContainer {
            return nil
        }
        die("Unknown tree \(self)")
    }

    package var mostRecentWindowRecursive: Window? {
        self as? Window ?? mostRecentChild?.mostRecentWindowRecursive
    }

    package var anyLeafWindowRecursive: Window? {
        if let window = self as? Window {
            return window
        }
        for child in children {
            if let window = child.anyLeafWindowRecursive {
                return window
            }
        }
        return nil
    }

    // Doesn't contain at least one window
    package var isEffectivelyEmpty: Bool {
        anyLeafWindowRecursive == nil
    }

    @MainActor
    package var hWeight: CGFloat {
        get { getWeight(.h) }
        set { setWeight(.h, newValue) }
    }

    @MainActor
    package var vWeight: CGFloat {
        get { getWeight(.v) }
        set { setWeight(.v, newValue) }
    }

    /// Returns closest parent that has children in the specified direction relative to `self`
    package func closestParent(
        hasChildrenInDirection direction: CardinalDirection,
    ) -> (parent: Column, ownIndex: Int)? {
        let innermostChild = parentsWithSelf.first(where: { (node: TreeNode) -> Bool in
            guard let parent = node.parent else { return true }
            if let tilingParent = parent as? Column {
                return tilingParent.orientation == direction.orientation &&
                    (node.ownIndex.map { tilingParent.children.indices.contains($0 + direction.focusOffset) } ?? true)
            }
            return true
        })
        guard let innermostChild else { return nil }
        guard let parent = innermostChild.parent as? Column else { return nil }
        check(parent.orientation == direction.orientation)
        return innermostChild.ownIndex.map { (parent, $0) }
    }

    package var isUnconventionalContainer: Bool {
            self is NativeMinimizedWindowsContainer ||
            self is NativeFullscreenWindowsContainer ||
            self is HiddenAppWindowsContainer ||
            self is ExcludedWindowsContainer
    }

    package var tilingNodeOrNil: TilingTreeNode? {
        if let window = self as? Window {
            return .window(window)
        }
        if let container = self as? Column {
            return .tilingContainer(container)
        }
        return nil
    }
}

package enum TilingTreeNode {
    case window(Window)
    case tilingContainer(Column)
}
