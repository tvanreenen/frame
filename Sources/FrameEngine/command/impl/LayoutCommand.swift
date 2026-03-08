import AppKit
import Common

struct LayoutCommand: Command {
    let args: LayoutCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        let targetDescription = args.toggleBetween.val.first(where: { !window.matchesDescription($0) })
            ?? args.toggleBetween.val.first.orDie()
        if window.matchesDescription(targetDescription) { return false }
        switch targetDescription {
            case .tiling:
                guard let parent = window.parent else { return false }
                if parent is PopupWindowsContainer {
                    return false
                }
                if parent is NativeMinimizedWindowsContainer ||
                    parent is NativeFullscreenWindowsContainer ||
                    parent is HiddenAppWindowsContainer
                {
                    return io.err("Can't change layout for macOS minimized, fullscreen windows or windows of hidden apps. This behavior is subject to change")
                }
                if parent is Column {
                    return true // Nothing to do
                }
                guard let workspace = parent as? Workspace else { return false }
                window.lastFloatingSize = try await window.getAxSize() ?? window.lastFloatingSize
                try await window.relayoutWindow(on: workspace, forceTile: true)
                return true
            case .floating:
                let workspace = target.workspace
                window.bindAsFloatingWindow(to: workspace)
                if let size = window.lastFloatingSize { window.setAxFrame(nil, size) }
                return true
        }
    }
}

extension Window {
    fileprivate func matchesDescription(_ layout: LayoutCmdArgs.LayoutDescription) -> Bool {
        return switch layout {
            case .tiling:   parent is Column
            case .floating: parent is Workspace
        }
    }
}
