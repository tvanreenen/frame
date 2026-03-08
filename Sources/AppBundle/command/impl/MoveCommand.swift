import AppKit
import Common

struct MoveCommand: Command {
    let args: MoveCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) -> Bool {
        let direction = args.direction.val
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let currentWindow = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        guard let parent = currentWindow.parent else { return false }
        if let parent = parent as? Column {
            switch direction.orientation {
                case .h: // left/right — push window to adjacent column
                    return moveWindowBetweenColumns(currentWindow, direction: direction, args, io)
                case .v: // up/down — reorder within column
                    guard parent.orientation == .v else { return true }
                    let indexOfCurrent = currentWindow.ownIndex.orDie()
                    let indexOfTarget = indexOfCurrent + direction.focusOffset
                    guard parent.children.indices.contains(indexOfTarget) else { return true }
                    let prevBinding = currentWindow.unbindFromParent()
                    currentWindow.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfTarget)
                    return true
            }
        }
        if parent is Workspace { return io.err("moving floating windows isn't yet supported") }
        if parent is MacosMinimizedWindowsContainer || parent is MacosFullscreenWindowsContainer || parent is MacosHiddenAppsWindowsContainer {
            return io.err(moveOutMacosUnconventionalWindow)
        }
        return false
    }
}

private let moveOutMacosUnconventionalWindow =
    "moving macOS fullscreen, minimized windows and windows of hidden apps isn't yet supported"

@MainActor private func moveWindowBetweenColumns(
    _ window: Window,
    direction: CardinalDirection,
    _ args: MoveCmdArgs,
    _ io: CmdIo,
) -> Bool {
    guard let workspace = window.nodeWorkspace else { return false }
    let cols = workspace.columns
    guard let currentColumn = window.column,
          let currentIndex = cols.firstIndex(of: currentColumn)
    else {
        // Defensive only. Normal runtime paths should always place tiled windows in a column.
        return true
    }

    let targetIndex = currentIndex + direction.focusOffset
    let targetColumn: Column
    if cols.indices.contains(targetIndex) {
        targetColumn = cols[targetIndex]
    } else {
        switch args.boundariesAction {
            case .stop:
                return true
            case .fail:
                return false
            case .createImplicitContainer:
                if args.boundaries != .workspace {
                    return io.err("create-implicit-container only supports --boundaries workspace")
                }
                if direction == .left {
                    targetColumn = workspace.addColumn(before: currentColumn)
                } else if direction == .right {
                    targetColumn = workspace.addColumn(after: currentColumn)
                } else {
                    return io.err("Invalid move direction for column move: \(direction.rawValue)")
                }
        }
    }
    window.bind(to: targetColumn, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    return true
}
