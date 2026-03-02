import AppKit
import Common

struct LayoutCommand: Command {
    let args: LayoutCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
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
                switch parent.cases {
                    case .macosPopupWindowsContainer:
                        return false
                    case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                        return io.err("Can't change layout for macOS minimized, fullscreen windows or windows of hidden apps. This behavior is subject to change")
                    case .tilingContainer:
                        return true // Nothing to do
                    case .workspace(let workspace):
                        window.lastFloatingSize = try await window.getAxSize() ?? window.lastFloatingSize
                        try await window.relayoutWindow(on: workspace, forceTile: true)
                        return true
                }
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
