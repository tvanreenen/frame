import AppKit
import Common

struct ResizeCommand: Command { // todo cover with tests
    let args: ResizeCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }

        let candidates = target.windowOrNil?.parentsWithSelf
            .filter { ($0.parent as? Column)?.layout == .tiles }
            ?? []

        let orientation: Orientation?
        let parent: Column?
        let node: TreeNode?
        switch args.dimension.val {
            case .width:
                orientation = .h
                node = candidates.first(where: { ($0.parent as? Column)?.orientation == orientation })
                parent = node?.parent as? Column
            case .height:
                orientation = .v
                node = candidates.first(where: { ($0.parent as? Column)?.orientation == orientation })
                parent = node?.parent as? Column
            case .smart:
                node = candidates.first
                parent = node?.parent as? Column
                orientation = parent?.orientation
            case .smartOpposite:
                orientation = (candidates.first?.parent as? Column)?.orientation.opposite
                node = candidates.first(where: { ($0.parent as? Column)?.orientation == orientation })
                parent = node?.parent as? Column
        }
        guard let parent else {
            // Focused floating windows are intentionally ignored by resize.
            if let window = target.windowOrNil, window.parent is Workspace {
                return true
            }
            return false
        }
        guard let orientation else { return false }
        guard let node else { return false }
        // When the node is the last child its active boundary is the leading edge
        // (left for columns, top for rows), so directional resize must be flipped.
        let directionSign: CGFloat = parent.children.last == node ? -1 : 1
        let diff: CGFloat = switch args.units.val {
            case .set(let unit): CGFloat(unit) - node.getWeight(orientation)
            case .add(let unit): directionSign * CGFloat(unit)
            case .subtract(let unit): directionSign * -CGFloat(unit)
        }

        guard let childDiff = diff.div(parent.children.count - 1) else { return false }
        parent.children.lazy
            .filter { $0 != node }
            .forEach { $0.setWeight(parent.orientation, $0.getWeight(parent.orientation) - childDiff) }

        node.setWeight(orientation, node.getWeight(orientation) + diff)
        return true
    }
}
