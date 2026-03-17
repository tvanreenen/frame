import Common
import Foundation

enum EffectiveLeaf {
    case window(Window)
    case emptyWorkspace(Workspace)
}
extension LiveFocus {
    var asLeaf: EffectiveLeaf {
        if let windowOrNil { .window(windowOrNil) } else { .emptyWorkspace(workspace) }
    }
}

/// This object should be only passed around but never memorized
/// Alternative name: ResolvedFocus
package struct LiveFocus: AeroAny, Equatable {
    package let windowOrNil: Window?
    package var workspace: Workspace

    @MainActor package var frozen: FrozenFocus {
        return FrozenFocus(
            windowId: windowOrNil?.windowId,
            workspaceName: workspace.name,
            monitorId: workspace.workspaceMonitor.monitorId ?? 0,
        )
    }
}

/// "old", "captured", "frozen in time" Focus
/// It's safe to keep a hard reference to this object.
/// Unlike in LiveFocus, information inside FrozenFocus isn't guaranteed to be self-consistent.
/// window - workspace - monitor relation could change since the object is created
package struct FrozenFocus: AeroAny, Equatable, Sendable {
    package let windowId: FrameWindowId?
    package let workspaceName: String
    // monitorId is not part of focus identity. We keep it only to detect monitor transitions for side effects.
    package let monitorId: Int // 0-based

    @MainActor package var live: LiveFocus { // Important: don't access focus.monitorId here. monitorId is not part of the focus. Always prefer workspace
        currentSession.liveFocus(for: self)
    }
}

@MainActor
extension AppSession {
    package var focus: LiveFocus { initializedFocus().live }

    func liveFocus(for frozenFocus: FrozenFocus) -> LiveFocus {
        let window: Window? = frozenFocus.windowId.flatMap { Window.get(byId: $0) }
        let workspace = workspace(byName: frozenFocus.workspaceName)

        let workspaceFocus = workspace.toLiveFocus()
        let windowFocus = window?.toLiveFocusOrNil() ?? workspaceFocus

        return workspaceFocus.workspace != windowFocus.workspace
            ? workspaceFocus
            : windowFocus
    }

    @discardableResult
    func setFocus(to newFocus: LiveFocus) -> Bool {
        if initializedFocus() == newFocus.frozen { return true }
        let oldFocus = focus
        if oldFocus.workspace != newFocus.workspace {
            oldFocus.windowOrNil?.markAsMostRecentChild()
        }

        focusState = newFocus.frozen
        let status = newFocus.workspace.workspaceMonitor.setActiveWorkspace(newFocus.workspace)

        newFocus.windowOrNil?.markAsMostRecentChild()
        return status
    }

    var prevFocusedWorkspace: Workspace? {
        prevFocusedWorkspaceName.map { workspace(byName: $0) }
    }

    func checkFocusCallbacks() {
        if refreshSessionEvent?.isStartup == true {
            return
        }
        let focus = focus
        let frozenFocus = focus.frozen
        var hasFocusedMonitorChanged = false
        var newFocusedWorkspace: String? = nil
        if frozenFocus.workspaceName != initializedLastKnownFocus().workspaceName {
            newFocusedWorkspace = frozenFocus.workspaceName
            prevFocusedWorkspaceName = initializedLastKnownFocus().workspaceName
            prevFocusedWorkspaceDate = .now
        }
        if frozenFocus.monitorId != initializedLastKnownFocus().monitorId {
            hasFocusedMonitorChanged = true
        }
        lastKnownFocus = frozenFocus

        if focusCallbacksRecursionGuard { return }
        focusCallbacksRecursionGuard = true
        defer { focusCallbacksRecursionGuard = false }
        if hasFocusedMonitorChanged {
            followFocusedMonitorWithMouseIfNeeded(focus)
        }
        if let newFocusedWorkspace {
            runWorkspaceChangeHook(newFocusedWorkspace)
        }
    }

    private func followFocusedMonitorWithMouseIfNeeded(_ focus: LiveFocus) {
        let rect = focus.workspace.workspaceMonitor.rect
        if rect.contains(currentSession.platformServices.mouseLocation()) { return }
        currentSession.platformServices.followFocusedMonitorWithMouse(rect.center)
    }
}

/// Global focus.
/// Commands must be cautious about accessing this property directly. There are legitimate cases.
/// But, in general, commands must firstly check --window-id, --workspace, FRAME_WINDOW_ID env and
/// FRAME_WORKSPACE env before accessing the global focus.
@MainActor package var focus: LiveFocus { currentSession.focus }

@MainActor func setFocus(to newFocus: LiveFocus) -> Bool {
    currentSession.setFocus(to: newFocus)
}
extension Window {
    @MainActor func focusWindow() -> Bool {
        if let focus = toLiveFocusOrNil() {
            return currentSession.setFocus(to: focus)
        } else {
            // todo We should also exit-native-hidden/unminimize[/exit-native-fullscreen?] window if we want to fix ID-B6E178F2
            //      and retry to focus the window. Otherwise, it's not possible to focus minimized/hidden windows
            return false
        }
    }

    @MainActor func toLiveFocusOrNil() -> LiveFocus? { visualWorkspace.map { LiveFocus(windowOrNil: self, workspace: $0) } }
}
extension Workspace {
    @MainActor package func focusWorkspace() -> Bool { currentSession.setFocus(to: toLiveFocus()) }

    func toLiveFocus() -> LiveFocus {
        // TODO: prefer excluded/unconventional windows over an empty columns root when no tiled window is present.
        if let wd = mostRecentWindowRecursive ?? anyLeafWindowRecursive {
            LiveFocus(windowOrNil: wd, workspace: self)
        } else {
            LiveFocus(windowOrNil: nil, workspace: self) // emptyWorkspace
        }
    }
}

@MainActor var prevFocusedWorkspaceDate: Date {
    get { currentSession.prevFocusedWorkspaceDate }
    set { currentSession.prevFocusedWorkspaceDate = newValue }
}
@MainActor var prevFocusedWorkspace: Workspace? { currentSession.prevFocusedWorkspace }

// Should be called in refreshSession
@MainActor func checkFocusCallbacks() {
    currentSession.checkFocusCallbacks()
}
