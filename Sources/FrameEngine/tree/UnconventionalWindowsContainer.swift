import AppKit
import Common

final class NativeFullscreenWindowsContainer: NonLeafTreeNode {
    @available(*, unavailable)
    override init(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        fatalError("Use init(parent: Workspace)")
    }

    @MainActor
    init(parent: Workspace) {
        super.init(parent: parent, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}

/// The container for macOS windows of hidden apps
final class HiddenAppWindowsContainer: NonLeafTreeNode {
    @available(*, unavailable)
    override init(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        fatalError("Use init(parent: Workspace)")
    }

    @MainActor
    init(parent: Workspace) {
        super.init(parent: parent, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}

@MainActor let nativeMinimizedWindowsContainer = NativeMinimizedWindowsContainer()
final class NativeMinimizedWindowsContainer: NonLeafTreeNode {
    @available(*, unavailable)
    override init(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        fatalError("Use the shared singleton container")
    }

    @MainActor
    fileprivate init() {
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}

@MainActor let popupWindowsContainer = PopupWindowsContainer()
/// The container for macOS objects that are windows from AX perspective but from human perspective they are not even
/// dialogs. E.g. Sonoma (macOS 14) keyboard layout switch
final class PopupWindowsContainer: NonLeafTreeNode {
    @available(*, unavailable)
    override init(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) {
        fatalError("Use the shared singleton container")
    }

    @MainActor
    fileprivate init() {
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }
}
