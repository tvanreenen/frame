import Common

// MARK: - Workspace extensions

extension Workspace {
    /// The root h-tiles tiling container for the columns layout.
    @MainActor var columnsRoot: Column { rootTilingContainer }

    /// The ordered list of column containers (v-tiles direct children of columnsRoot).
    @MainActor var columns: [Column] {
        columnsRoot.children.compactMap { $0 as? Column }
    }

    /// The column containing the currently focused window, or nil.
    @MainActor var focusedColumn: Column? {
        focus.windowOrNil?.column
    }

    /// Adds a new v-tiles column after `afterColumn`. Appends at end if `afterColumn` is nil.
    @MainActor
    @discardableResult
    func addColumn(after afterColumn: Column?) -> Column {
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
    func addColumn(before beforeColumn: Column) -> Column {
        let index = beforeColumn.ownIndex ?? 0
        return Column.newVTiles(parent: columnsRoot, adaptiveWeight: WEIGHT_AUTO, index: index)
    }

    /// Removes `column`, moving all its windows to the left neighbor (or right if first).
    /// If it's the only column, windows become floating.
    @MainActor
    func removeColumn(_ column: Column) {
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
    @MainActor var isColumn: Bool {
        guard let root = parent as? Column else { return false }
        return root.parent is Workspace && root.orientation == .h && orientation == .v
    }

    /// Index of this column in columnsRoot.children, if it is a column.
    @MainActor var columnIndex: Int? {
        isColumn ? ownIndex : nil
    }
}

// MARK: - Window extensions

extension Window {
    /// The v-tiles column container this window lives in, if any.
    @MainActor var column: Column? {
        guard let col = parent as? Column, col.isColumn else { return nil }
        return col
    }

    /// Index of this window within its column (0-based).
    @MainActor var indexInColumn: Int? {
        column != nil ? ownIndex : nil
    }
}
