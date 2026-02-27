import AppKit
import Common

struct MoveCommand: Command {
    let args: MoveCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let direction = args.direction.val
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let currentWindow = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        guard let parent = currentWindow.parent else { return false }
        switch parent.cases {
            case .tilingContainer(let parent):
                switch direction.orientation {
                    case .h: // left/right — push window to adjacent column
                        return moveWindowBetweenColumns(currentWindow, direction: direction, io)
                    case .v: // up/down — reorder within column
                        guard parent.orientation == .v else { return true }
                        let indexOfCurrent = currentWindow.ownIndex.orDie()
                        let indexOfTarget = indexOfCurrent + direction.focusOffset
                        guard parent.children.indices.contains(indexOfTarget) else { return true }
                        let prevBinding = currentWindow.unbindFromParent()
                        currentWindow.bind(to: parent, adaptiveWeight: prevBinding.adaptiveWeight, index: indexOfTarget)
                        return true
                }
            case .workspace: // floating window
                return io.err("moving floating windows isn't yet supported")
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                return io.err(moveOutMacosUnconventionalWindow)
            case .macosPopupWindowsContainer:
                return false
        }
    }
}

private let moveOutMacosUnconventionalWindow =
    "moving macOS fullscreen, minimized windows and windows of hidden apps isn't yet supported"

@MainActor private func moveWindowBetweenColumns(
    _ window: Window,
    direction: CardinalDirection,
    _ io: CmdIo,
) -> Bool {
    guard let workspace = window.nodeWorkspace else { return false }
    let cols = workspace.columns
    guard let currentColumn = window.column,
          let currentIndex = cols.firstIndex(of: currentColumn)
    else {
        // Window is not in a column (shouldn't happen in normal usage)
        return true
    }

    let targetIndex = currentIndex + direction.focusOffset
    let targetColumn: TilingContainer
    if cols.indices.contains(targetIndex) {
        targetColumn = cols[targetIndex]
    } else if direction == .right {
        targetColumn = workspace.addColumn(after: currentColumn)
    } else {
        targetColumn = workspace.addColumn(before: currentColumn)
    }

    window.bind(to: targetColumn, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    return true
}
