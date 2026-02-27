import Common

// MARK: - Workspace extensions

extension Workspace {
    /// The root h-tiles tiling container for the columns layout.
    @MainActor var columnsRoot: TilingContainer { rootTilingContainer }

    /// The ordered list of column containers (v-tiles direct children of columnsRoot).
    @MainActor var columns: [TilingContainer] {
        columnsRoot.children.compactMap { $0 as? TilingContainer }
    }

    /// The column containing the currently focused window, or nil.
    @MainActor var focusedColumn: TilingContainer? {
        focus.windowOrNil?.column
    }

    /// Adds a new v-tiles column after `afterColumn`. Appends at end if `afterColumn` is nil.
    @MainActor
    @discardableResult
    func addColumn(after afterColumn: TilingContainer?) -> TilingContainer {
        let root = columnsRoot
        let index: Int
        if let afterColumn, let idx = afterColumn.ownIndex {
            index = idx + 1
        } else {
            index = INDEX_BIND_LAST
        }
        return TilingContainer.newVTiles(parent: root, adaptiveWeight: WEIGHT_AUTO, index: index)
    }

    /// Adds a new v-tiles column before `beforeColumn`.
    @MainActor
    @discardableResult
    func addColumn(before beforeColumn: TilingContainer) -> TilingContainer {
        let index = beforeColumn.ownIndex ?? 0
        return TilingContainer.newVTiles(parent: columnsRoot, adaptiveWeight: WEIGHT_AUTO, index: index)
    }

    /// Removes `column`, moving all its windows to the left neighbor (or right if first).
    /// If it's the only column, windows become floating.
    @MainActor
    func removeColumn(_ column: TilingContainer) {
        let cols = columns
        guard let idx = cols.firstIndex(of: column) else { return }

        let targetColumn: TilingContainer?
        if idx > 0 {
            targetColumn = cols[idx - 1]
        } else if cols.count > 1 {
            targetColumn = cols[idx + 1]
        } else {
            targetColumn = nil
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

// MARK: - TilingContainer extensions

extension TilingContainer {
    /// True if this container is a direct column child of the workspace's h-tiles root.
    @MainActor var isColumn: Bool {
        guard let root = parent as? TilingContainer else { return false }
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
    @MainActor var column: TilingContainer? {
        guard let col = parent as? TilingContainer, col.isColumn else { return nil }
        return col
    }

    /// Index of this window within its column (0-based).
    @MainActor var indexInColumn: Int? {
        column != nil ? ownIndex : nil
    }
}
