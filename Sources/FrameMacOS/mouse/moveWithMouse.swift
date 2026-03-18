import AppKit
import Common
import FrameEngine

@MainActor
private var moveWithMouseTask: Task<(), any Error>? = nil

func movedObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    let windowId = ax.containingWindowId()
    let notif = notif as String
    let session = AppSession.fromCallbackContext(data)
    Task { @MainActor in
        let session = session ?? currentSession
        guard let windowId, let window = Window.get(byPlatformWindowId: windowId), try await isManipulatedWithMouse(window) else {
            session.scheduleRefreshSession(.ax(notif))
            return
        }
        moveWithMouseTask?.cancel()
        moveWithMouseTask = Task {
            try checkCancellation()
            try await session.runLightSession(.ax(notif)) {
                try await moveWithMouse(window)
            }
        }
    }
}

@MainActor
private func moveWithMouse(_ window: Window) async throws { // todo cover with tests
    guard let parent = window.parent else { return }
    if parent is Column {
        moveTilingWindow(window)
    }
}

@MainActor
private func moveTilingWindow(_ window: Window) {
    currentSession.currentlyManipulatedWithMouseWindowId = window.windowId
    window.lastAppliedLayoutPhysicalRect = nil
    let pointer = currentSession.platformServices.mouseLocation()
    let targetWorkspace = pointer.monitorApproximation.activeWorkspace
    let swapTarget = pointer.findIn(tree: targetWorkspace.columnsRoot, virtual: false)?.takeIf { $0 != window }
    if targetWorkspace != window.nodeWorkspace { // Move window to a different monitor
        let bindingData: BindingData = if let swapTarget, let parent = swapTarget.parent as? Column, let targetRect = swapTarget.lastAppliedLayoutPhysicalRect {
            pointer.getProjection(parent.orientation) >= targetRect.center.getProjection(parent.orientation)
                ? BindingData(parent: parent, adaptiveWeight: WEIGHT_AUTO, index: swapTarget.ownIndex.orDie() + 1)
                : BindingData(parent: parent, adaptiveWeight: WEIGHT_AUTO, index: swapTarget.ownIndex.orDie())
        } else {
            targetWorkspace.transferredTilingWindowBindingData()
        }
        window.bind(to: bindingData.parent, adaptiveWeight: bindingData.adaptiveWeight, index: bindingData.index)
    } else if let swapTarget {
        swapWindows(window, swapTarget)
    }
}

@MainActor
func swapWindows(_ window1: Window, _ window2: Window) {
    if window1 == window2 { return }
    guard let index1 = window1.ownIndex else { return }
    guard let index2 = window1.ownIndex else { return }

    if index1 < index2 {
        let binding2 = window2.unbindFromParent()
        let binding1 = window1.unbindFromParent()

        window2.bind(to: binding1.parent, adaptiveWeight: binding1.adaptiveWeight, index: binding1.index)
        window1.bind(to: binding2.parent, adaptiveWeight: binding2.adaptiveWeight, index: binding2.index)
    } else {
        let binding1 = window1.unbindFromParent()
        let binding2 = window2.unbindFromParent()

        window1.bind(to: binding2.parent, adaptiveWeight: binding2.adaptiveWeight, index: binding2.index)
        window2.bind(to: binding1.parent, adaptiveWeight: binding1.adaptiveWeight, index: binding1.index)
    }
}

extension CGPoint {
    @MainActor
    func findIn(tree: Column, virtual: Bool) -> Window? {
        let point = self
        let target: TreeNode? = tree.children.first(where: {
            (virtual ? $0.lastAppliedLayoutVirtualRect : $0.lastAppliedLayoutPhysicalRect)?.contains(point) == true
        })
        guard let target else { return nil }
        return switch target.tilingNodeOrNil {
            case .window(let window):
                window
            case .tilingContainer(let container):
                findIn(tree: container, virtual: virtual)
            case nil:
                illegalChildParentRelation(child: target, parent: target.parent)
        }
    }
}
