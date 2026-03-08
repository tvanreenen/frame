import Common

// MARK: - Workspace extensions

extension Workspace {
    /// The root h-tiles tiling container for the columns layout.
    @MainActor package var columnsRoot: Column { rootTilingContainer }

    /// The ordered list of column containers (v-tiles direct children of columnsRoot).
    @MainActor package var columns: [Column] {
        columnsRoot.children.compactMap { $0 as? Column }
    }

    /// The column containing the currently focused window, or nil.
    @MainActor package var focusedColumn: Column? {
        focus.windowOrNil?.column
    }

    /// Returns the column that should receive a newly tiled window.
    /// Uses the focused column when available, otherwise creates a new trailing column.
    @MainActor
    package func targetColumnForNewTilingWindow() -> Column {
        focusedColumn ?? addColumn(after: nil)
    }

    /// Binding data for placing a newly tiled window into the columns model.
    @MainActor
    package func newTilingWindowBindingData(index: Int = INDEX_BIND_LAST) -> BindingData {
        BindingData(
            parent: targetColumnForNewTilingWindow(),
            adaptiveWeight: WEIGHT_AUTO,
            index: index,
        )
    }

    /// Returns the column that should receive a tiled window moved in from elsewhere.
    /// Matches the existing normalization behavior by appending to the last column when possible.
    @MainActor
    package func targetColumnForTransferredTilingWindow() -> Column {
        columns.last ?? addColumn(after: nil)
    }

    /// Binding data for moving a tiled window into this workspace.
    @MainActor
    package func transferredTilingWindowBindingData(index: Int = INDEX_BIND_LAST) -> BindingData {
        BindingData(
            parent: targetColumnForTransferredTilingWindow(),
            adaptiveWeight: WEIGHT_AUTO,
            index: index,
        )
    }

    /// Adds a new v-tiles column after `afterColumn`. Appends at end if `afterColumn` is nil.
    @MainActor
    @discardableResult
    package func addColumn(after afterColumn: Column?) -> Column {
        let root = columnsRoot
        let index: Int = if let afterColumn, let idx = afterColumn.ownIndex {
            idx + 1
        } else {
            INDEX_BIND_LAST
        }
        return Column.newVTiles(parent: root, adaptiveWeight: WEIGHT_AUTO, index: index)
    }

    /// Adds a new v-tiles column before `beforeColumn`.
    @MainActor
    @discardableResult
    package func addColumn(before beforeColumn: Column) -> Column {
        let index = beforeColumn.ownIndex ?? 0
        return Column.newVTiles(parent: columnsRoot, adaptiveWeight: WEIGHT_AUTO, index: index)
    }

    /// Removes `column`, moving all its windows to the left neighbor (or right if first).
    /// If it's the only column, windows become floating.
    @MainActor
    package func removeColumn(_ column: Column) {
        let cols = columns
        guard let idx = cols.firstIndex(of: column) else { return }

        let targetColumn: Column? = if idx > 0 {
            cols[idx - 1]
        } else if cols.count > 1 {
            cols[idx + 1]
        } else {
            nil
        }

        for window in Array(column.children).compactMap({ $0 as? Window }) {
            if let target = targetColumn {
                window.bind(to: target, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
            } else {
                window.bindAsFloatingWindow(to: self)
            }
        }

        if column.children.isEmpty {
            column.unbindFromParent()
        }
    }
}

// MARK: - Column extensions

extension Column {
    /// True if this container is a direct column child of the workspace's h-tiles root.
    @MainActor package var isColumn: Bool {
        guard let root = parent as? Column else { return false }
        return root.parent is Workspace && root.orientation == .h && orientation == .v
    }

    /// Index of this column in columnsRoot.children, if it is a column.
    @MainActor package var columnIndex: Int? {
        isColumn ? ownIndex : nil
    }
}

// MARK: - Window extensions

extension Window {
    /// The v-tiles column container this window lives in, if any.
    @MainActor package var column: Column? {
        guard let col = parent as? Column, col.isColumn else { return nil }
        return col
    }

    /// Index of this window within its column (0-based).
    @MainActor package var indexInColumn: Int? {
        column != nil ? ownIndex : nil
    }
}
