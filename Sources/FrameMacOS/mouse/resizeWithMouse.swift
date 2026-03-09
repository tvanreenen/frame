import AppKit
import Common
import FrameEngine

@MainActor
private var resizeWithMouseTask: Task<(), any Error>? = nil

func resizedObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    let notif = notif as String
    let windowId = ax.containingWindowId()
    let session = AppSession.fromCallbackContext(data)
    Task { @MainActor in
        let session = session ?? currentSession
        guard let windowId, let window = Window.get(byId: windowId), try await isManipulatedWithMouse(window) else {
            session.scheduleRefreshSession(.ax(notif))
            return
        }
        resizeWithMouseTask?.cancel()
        resizeWithMouseTask = Task {
            try checkCancellation()
            try await session.runLightSession(.ax(notif)) {
                try await resizeWithMouse(window)
            }
        }
    }
}

@MainActor
func resetManipulatedWithMouseIfPossible() async throws {
    if currentSession.currentlyManipulatedWithMouseWindowId != nil {
        currentSession.currentlyManipulatedWithMouseWindowId = nil
        for workspace in Workspace.all {
            workspace.resetResizeWeightBeforeResizeRecursive()
        }
        currentSession.scheduleRefreshSession(.resetManipulatedWithMouse, optimisticallyPreLayoutWorkspaces: true)
    }
}

private let adaptiveWeightBeforeResizeWithMouseKey = TreeNodeUserDataKey<CGFloat>(key: "adaptiveWeightBeforeResizeWithMouseKey")

@MainActor
private func resizeWithMouse(_ window: Window) async throws { // todo cover with tests
    resetClosedWindowsCache()
    guard let parent = window.parent else { return }
    guard parent is Column else { return } // Nothing to do for excluded or unconventional windows
    guard let rect = try await window.getRect() else { return }
    guard let lastAppliedLayoutRect = window.lastAppliedLayoutPhysicalRect else { return }
    let (lParent, lOwnIndex) = window.closestParent(hasChildrenInDirection: .left) ?? (nil, nil)
    let (dParent, dOwnIndex) = window.closestParent(hasChildrenInDirection: .down) ?? (nil, nil)
    let (uParent, uOwnIndex) = window.closestParent(hasChildrenInDirection: .up) ?? (nil, nil)
    let (rParent, rOwnIndex) = window.closestParent(hasChildrenInDirection: .right) ?? (nil, nil)
    let table: [(CGFloat, Column?, Int?, Int?)] = [
        (lastAppliedLayoutRect.minX - rect.minX, lParent, 0,                        lOwnIndex),               // Horizontal, to the left of the window
        (rect.maxY - lastAppliedLayoutRect.maxY, dParent, dOwnIndex.map { $0 + 1 }, dParent?.children.count), // Vertical, to the down of the window
        (lastAppliedLayoutRect.minY - rect.minY, uParent, 0,                        uOwnIndex),               // Vertical, to the up of the window
        (rect.maxX - lastAppliedLayoutRect.maxX, rParent, rOwnIndex.map { $0 + 1 }, rParent?.children.count), // Horizontal, to the right of the window
    ]
    for (diff, parent, startIndex, pastTheEndIndex) in table {
        if let parent, let startIndex, let pastTheEndIndex, pastTheEndIndex - startIndex > 0 && abs(diff) > 5 { // 5 pixels should be enough to fight with accumulated floating precision error
            let siblingDiff = diff.div(pastTheEndIndex - startIndex).orDie()
            let orientation = parent.orientation

            window.parentsWithSelf.lazy
                .prefix(while: { $0 != parent })
                .filter {
                    let parent = $0.parent as? Column
                    return parent?.orientation == orientation
                }
                .forEach { $0.setWeight(orientation, $0.getWeightBeforeResize(orientation) + diff) }
            for sibling in parent.children[startIndex ..< pastTheEndIndex] {
                sibling.setWeight(orientation, sibling.getWeightBeforeResize(orientation) - siblingDiff)
            }
        }
    }
    currentSession.currentlyManipulatedWithMouseWindowId = window.windowId
}

extension TreeNode {
    @MainActor
    fileprivate func getWeightBeforeResize(_ orientation: Orientation) -> CGFloat {
        let currentWeight = getWeight(orientation) // Check assertions
        return getUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
            ?? (lastAppliedLayoutVirtualRect?.getDimension(orientation) ?? currentWeight)
            .also { putUserData(key: adaptiveWeightBeforeResizeWithMouseKey, data: $0) }
    }

    fileprivate func resetResizeWeightBeforeResizeRecursive() {
        cleanUserData(key: adaptiveWeightBeforeResizeWithMouseKey)
        for child in children {
            child.resetResizeWeightBeforeResizeRecursive()
        }
    }
}
