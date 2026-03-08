import AppKit
import Common

extension AppSession {
    var allWorkspaces: [Workspace] {
        workspaceNameToWorkspace.values.sorted()
    }

    func workspace(byName name: String) -> Workspace {
        if let existing = workspaceNameToWorkspace[name] {
            return existing
        } else {
            let workspace = Workspace(name)
            workspaceNameToWorkspace[name] = workspace
            return workspace
        }
    }

    func garbageCollectUnusedWorkspaces() {
        for name in runtimeContext.config.persistentWorkspaces {
            _ = workspace(byName: name)
        }
        workspaceNameToWorkspace = workspaceNameToWorkspace.filter { (_, workspace: Workspace) in
            runtimeContext.config.persistentWorkspaces.contains(workspace.name) ||
                !workspace.isEffectivelyEmpty ||
                workspace.isVisible ||
                workspace.name == focus.workspace.name
        }
    }

    func isWorkspaceVisible(_ workspace: Workspace) -> Bool {
        visibleWorkspaceToScreenPoint.keys.contains(workspace)
    }

    func workspaceMonitor(for workspace: Workspace) -> Monitor {
        workspace.forceAssignedMonitor
            ?? visibleWorkspaceToScreenPoint[workspace]?.monitorApproximation
            ?? workspace.assignedMonitorPoint?.monitorApproximation
            ?? mainMonitor
    }

    func activeWorkspace(for monitor: Monitor) -> Workspace {
        if let existing = screenPointToVisibleWorkspace[monitor.rect.topLeftCorner] {
            return existing
        }
        rearrangeWorkspacesOnMonitors()
        return activeWorkspace(for: monitor)
    }

    @discardableResult
    func setActiveWorkspace(_ workspace: Workspace, on screen: CGPoint) -> Bool {
        if !isValidAssignment(workspace: workspace, screen: screen) {
            return false
        }
        if let prevMonitorPoint = visibleWorkspaceToScreenPoint[workspace] {
            visibleWorkspaceToScreenPoint.removeValue(forKey: workspace)
            screenPointToPrevVisibleWorkspace[prevMonitorPoint] =
                screenPointToVisibleWorkspace.removeValue(forKey: prevMonitorPoint)?.name
        }
        if let prevWorkspace = screenPointToVisibleWorkspace[screen] {
            screenPointToPrevVisibleWorkspace[screen] =
                screenPointToVisibleWorkspace.removeValue(forKey: screen)?.name
            visibleWorkspaceToScreenPoint.removeValue(forKey: prevWorkspace)
        }
        visibleWorkspaceToScreenPoint[workspace] = screen
        screenPointToVisibleWorkspace[screen] = workspace
        workspace.assignedMonitorPoint = screen
        return true
    }

    func gcMonitors() {
        if screenPointToVisibleWorkspace.count != monitors.count {
            rearrangeWorkspacesOnMonitors()
        }
    }

    // The returned workspace must be invisible and it must belong to the requested monitor
    func getStubWorkspace(for monitor: Monitor) -> Workspace {
        getStubWorkspace(forPoint: monitor.rect.topLeftCorner)
    }

    private func getStubWorkspace(forPoint point: CGPoint) -> Workspace {
        if let prev = screenPointToPrevVisibleWorkspace[point].map({ workspace(byName: $0) }),
           !prev.isVisible && prev.workspaceMonitor.rect.topLeftCorner == point && prev.forceAssignedMonitor == nil
        {
            return prev
        }
        if let candidate = allWorkspaces
            .first(where: { !$0.isVisible && $0.workspaceMonitor.rect.topLeftCorner == point })
        {
            return candidate
        }
        return (1 ... Int.max).lazy
            .map { self.workspace(byName: String($0)) }
            .first { $0.isEffectivelyEmpty && !$0.isVisible && !runtimeContext.config.persistentWorkspaces.contains($0.name) && $0.forceAssignedMonitor == nil }
            .orDie("Can't create empty workspace")
    }

    private func rearrangeWorkspacesOnMonitors() {
        var oldVisibleScreens: Set<CGPoint> = screenPointToVisibleWorkspace.keys.toSet()

        let newScreens = monitors.map(\.rect.topLeftCorner)
        var newScreenToOldScreenMapping: [CGPoint: CGPoint] = [:]
        for newScreen in newScreens {
            if let oldScreen = oldVisibleScreens.minBy({ ($0 - newScreen).vectorLength }) {
                check(oldVisibleScreens.remove(oldScreen) != nil)
                newScreenToOldScreenMapping[newScreen] = oldScreen
            }
        }

        let oldScreenPointToVisibleWorkspace = screenPointToVisibleWorkspace
        screenPointToVisibleWorkspace = [:]
        visibleWorkspaceToScreenPoint = [:]

        for newScreen in newScreens {
            if let existingVisibleWorkspace = newScreenToOldScreenMapping[newScreen].flatMap({ oldScreenPointToVisibleWorkspace[$0] }),
               setActiveWorkspace(existingVisibleWorkspace, on: newScreen)
            {
                continue
            }
            let stubWorkspace = getStubWorkspace(forPoint: newScreen)
            check(setActiveWorkspace(stubWorkspace, on: newScreen),
                  "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(newScreen)")
        }
    }

    private func isValidAssignment(workspace: Workspace, screen: CGPoint) -> Bool {
        if let forceAssigned = workspace.forceAssignedMonitor, forceAssigned.rect.topLeftCorner != screen {
            return false
        } else {
            return true
        }
    }
}

// The returned workspace must be invisible and it must belong to the requested monitor
@MainActor package func getStubWorkspace(for monitor: Monitor) -> Workspace {
    currentSession.getStubWorkspace(for: monitor)
}

package final class Workspace: TreeNode, NonLeafTreeNodeObject, Hashable, Comparable {
    package let name: String
    nonisolated private let nameLogicalSegments: StringLogicalSegments
    private var _rootTilingContainer: Column?
    /// `assignedMonitorPoint` must be interpreted only when the workspace is invisible
    fileprivate var assignedMonitorPoint: CGPoint? = nil

    /// Structural backing node for the columns model. Prefer `columnsRoot` at call sites.
    @MainActor
    var rootTilingContainer: Column {
        _rootTilingContainer.orDie("Workspace root tiling container must always exist")
    }

    @MainActor
    fileprivate init(_ name: String) {
        self.name = name
        self.nameLogicalSegments = name.toLogicalSegments()
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 0, index: 0)
        _rootTilingContainer = Column.newHTiles(parent: self, adaptiveWeight: 1, index: INDEX_BIND_LAST)
    }

    @MainActor package static var all: [Workspace] {
        currentSession.allWorkspaces
    }

    @MainActor package static func get(byName name: String) -> Workspace {
        currentSession.workspace(byName: name)
    }

    nonisolated package static func < (lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.nameLogicalSegments < rhs.nameLogicalSegments
    }

    override package func getWeight(_ targetOrientation: Orientation) -> CGFloat {
        workspaceMonitor.visibleRectPaddedByOuterGaps.getDimension(targetOrientation)
    }

    override package func setWeight(_ targetOrientation: Orientation, _ newValue: CGFloat) {
        die("It's not possible to change weight of Workspace")
    }

    @MainActor
    package var description: String {
        let description = [
            ("name", name),
            ("isVisible", String(isVisible)),
            ("isEffectivelyEmpty", String(isEffectivelyEmpty)),
            ("doKeepAlive", String(runtimeContext.config.persistentWorkspaces.contains(name))),
        ].map { "\($0.0): '\(String(describing: $0.1))'" }.joined(separator: ", ")
        return "Workspace(\(description))"
    }

    @MainActor
    package static func garbageCollectUnusedWorkspaces() {
        currentSession.garbageCollectUnusedWorkspaces()
    }

    nonisolated static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        check((lhs === rhs) == (lhs.name == rhs.name), "lhs: \(lhs) rhs: \(rhs)")
        return lhs === rhs
    }

    nonisolated package func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

extension Workspace {
    @MainActor
    package var isVisible: Bool { currentSession.isWorkspaceVisible(self) }
    @MainActor
    package var workspaceMonitor: Monitor {
        currentSession.workspaceMonitor(for: self)
    }
}

extension Monitor {
    @MainActor
    package var activeWorkspace: Workspace {
        currentSession.activeWorkspace(for: self)
    }

    @MainActor
    package func setActiveWorkspace(_ workspace: Workspace) -> Bool {
        rect.topLeftCorner.setActiveWorkspace(workspace)
    }
}

@MainActor
func gcMonitors() {
    currentSession.gcMonitors()
}

extension CGPoint {
    @MainActor
    fileprivate func setActiveWorkspace(_ workspace: Workspace) -> Bool {
        currentSession.setActiveWorkspace(workspace, on: self)
    }
}
