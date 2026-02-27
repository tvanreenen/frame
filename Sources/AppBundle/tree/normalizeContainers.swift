extension Workspace {
    /// Enforce the depth-2 columns invariant:
    ///   Workspace → Column(h,tiles) → [Column(v,tiles) → [Window, ...]]
    @MainActor func normalizeContainers() {
        normalizeColumnsStructure()
    }
}

extension Workspace {
    @MainActor fileprivate func normalizeColumnsStructure() {
        let root = rootTilingContainer

        // 1. Ensure root is h-tiles with tiles layout
        if root.orientation != .h { root.setOrientation(.h) }
        if root.layout != .tiles { root.layout = .tiles }

        // Pass A: fix Column children (make them proper v-tiles columns)
        //         and flatten any nested containers within each column
        for child in Array(root.children) {
            guard let column = child as? Column else { continue }
            if column.orientation != .v { column.setOrientation(.v) }
            flattenColumn(column)
        }

        // Pass B: remove empty columns
        for child in Array(root.children) {
            guard let column = child as? Column else { continue }
            if column.children.isEmpty {
                column.unbindFromParent()
            }
        }

        // Pass C: adopt orphan windows (Window children of root) into a column
        for child in Array(root.children) {
            guard let window = child as? Window else { continue }
            let targetColumn: Column
            if let last = columns.last {
                targetColumn = last
            } else {
                targetColumn = addColumn(after: nil)
            }
            window.bind(to: targetColumn, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
    }

    /// Recursively lift all leaf windows inside `column` up to be direct children of `column`.
    @MainActor fileprivate func flattenColumn(_ column: Column) {
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
