import AppKit
import Common

extension TreeNode {
    private func visit(node: TreeNode, result: inout [Window]) {
        if let node = node as? Window {
            result.append(node)
        }
        for child in node.children {
            visit(node: child, result: &result)
        }
    }
    var allLeafWindowsRecursive: [Window] {
        var result: [Window] = []
        visit(node: self, result: &result)
        return result
    }

    var ownIndex: Int? {
        guard let parent else { return nil }
        return parent.children.firstIndex(of: self).orDie()
    }

    var parents: [NonLeafTreeNodeObject] { parent.flatMap { [$0] + $0.parents } ?? [] }
    var parentsWithSelf: [TreeNode] { parent.flatMap { [self] + $0.parentsWithSelf } ?? [self] }

    /// Also see visualWorkspace
    var nodeWorkspace: Workspace? {
        self as? Workspace ?? parent?.nodeWorkspace
    }

    /// Also see: workspace
    @MainActor
    var visualWorkspace: Workspace? { nodeWorkspace ?? nodeMonitor?.activeWorkspace }

    @MainActor
    var nodeMonitor: Monitor? {
        if let workspace = self as? Workspace {
            return workspace.workspaceMonitor
        }
        if self is Window || self is Column || self is MacosFullscreenWindowsContainer || self is MacosHiddenAppsWindowsContainer {
            return parent?.nodeMonitor
        }
        if self is MacosMinimizedWindowsContainer || self is MacosPopupWindowsContainer {
            return nil
        }
        die("Unknown tree \(self)")
    }

    var mostRecentWindowRecursive: Window? {
        self as? Window ?? mostRecentChild?.mostRecentWindowRecursive
    }

    var anyLeafWindowRecursive: Window? {
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
    var isEffectivelyEmpty: Bool {
        anyLeafWindowRecursive == nil
    }

    @MainActor
    var hWeight: CGFloat {
        get { getWeight(.h) }
        set { setWeight(.h, newValue) }
    }

    @MainActor
    var vWeight: CGFloat {
        get { getWeight(.v) }
        set { setWeight(.v, newValue) }
    }

    /// Returns closest parent that has children in the specified direction relative to `self`
    func closestParent(
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

    var isMacosUnconventionalContainer: Bool {
        self is MacosMinimizedWindowsContainer ||
            self is MacosFullscreenWindowsContainer ||
            self is MacosHiddenAppsWindowsContainer ||
            self is MacosPopupWindowsContainer
    }

    var tilingNodeOrNil: TilingTreeNode? {
        if let window = self as? Window {
            return .window(window)
        }
        if let container = self as? Column {
            return .tilingContainer(container)
        }
        return nil
    }
}

enum TilingTreeNode {
    case window(Window)
    case tilingContainer(Column)
}
