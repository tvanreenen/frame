extension Workspace {
    /// Enforce the depth-2 columns invariant:
    ///   Workspace → Column(h,tiles) → [Column(v,tiles) → [Window, ...]]
    ///
    /// At this point normal runtime paths should already produce valid transferred/new tiling placement.
    /// The remaining work here is mostly defensive repair for legacy/test shapes plus routine empty-column cleanup.
    @MainActor func normalizeContainers() {
        normalizeColumnsStructure()
    }
}

extension Workspace {
    @MainActor private func normalizeColumnsStructure() {
        let root = rootTilingContainer
        normalizeColumnsRoot(root)
        normalizeLegacyColumnsUnderRoot(root)
        removeEmptyColumns(from: root)
        adoptUnexpectedRootLevelWindows(from: root)
    }

    @MainActor private func normalizeColumnsRoot(_ root: Column) {
        if root.orientation != .h { root.setOrientation(.h) }
    }

    @MainActor private func normalizeLegacyColumnsUnderRoot(_ root: Column) {
        for child in Array(root.children) {
            guard let column = child as? Column else { continue }
            if column.orientation != .v { column.setOrientation(.v) }
            liftNestedWindowsIntoColumn(column)
        }
    }

    @MainActor private func removeEmptyColumns(from root: Column) {
        for child in Array(root.children) {
            guard let column = child as? Column else { continue }
            if column.children.isEmpty {
                column.unbindFromParent()
            }
        }
    }

    @MainActor private func adoptUnexpectedRootLevelWindows(from root: Column) {
        let orphanWindows = Array(root.children.compactMap { $0 as? Window })
        guard !orphanWindows.isEmpty else { return }

        // This should now be defensive-only. Transfer/move paths should bind tiled windows into real columns directly.
        let targetColumn = targetColumnForTransferredTilingWindow()
        for window in orphanWindows {
            window.bind(to: targetColumn, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
    }

    /// Recursively lift all leaf windows inside `column` up to be direct children of `column`.
    /// This remains as a defensive repair for legacy/test trees and frozen-tree restore paths.
    @MainActor private func liftNestedWindowsIntoColumn(_ column: Column) {
        for child in Array(column.children) {
            guard let container = child as? Column else { continue }
            // Collect all windows from this nested container
            let windows = container.allLeafWindowsRecursive
            for window in windows {
                window.unbindFromParent()
                window.bind(to: column, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
            }
            // Container is now empty; unbind it
            if container.children.isEmpty {
                container.unbindFromParent()
            }
        }
    }
}
