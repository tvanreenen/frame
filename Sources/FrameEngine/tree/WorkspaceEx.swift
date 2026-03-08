import Common

extension Workspace {
    var floatingWindows: [Window] {
        children.filterIsInstance(of: Window.self)
    }

    @MainActor var nativeFullscreenWindowsContainer: NativeFullscreenWindowsContainer {
        let containers = children.filterIsInstance(of: NativeFullscreenWindowsContainer.self)
        return switch containers.count {
            case 0: NativeFullscreenWindowsContainer(parent: self)
            case 1: containers.singleOrNil().orDie()
            default: dieT("Workspace must contain zero or one NativeFullscreenWindowsContainer")
        }
    }

    @MainActor var hiddenAppWindowsContainer: HiddenAppWindowsContainer {
        let containers = children.filterIsInstance(of: HiddenAppWindowsContainer.self)
        return switch containers.count {
            case 0: HiddenAppWindowsContainer(parent: self)
            case 1: containers.singleOrNil().orDie()
            default: dieT("Workspace must contain zero or one HiddenAppWindowsContainer")
        }
    }

    @MainActor var forceAssignedMonitor: Monitor? {
        guard let monitorDescriptions = runtimeContext.config.workspaceToMonitorForceAssignment[name] else { return nil }
        let sortedMonitors = sortedMonitors
        return monitorDescriptions.lazy
            .compactMap { $0.resolveMonitor(sortedMonitors: sortedMonitors) }
            .first
    }
}
