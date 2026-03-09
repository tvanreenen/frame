import Common

struct FullscreenCommand: Command {
    let args: FullscreenCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        guard let window = target.windowOrNil else {
            return io.err(noWindowIsFocused)
        }
        guard window.parent is Column else {
            return io.err("Fullscreen overlay is only supported for tiled windows")
        }
        let newState: Bool = switch args.toggle {
            case .on: true
            case .off: false
            case .toggle: !window.isFullscreenOverlay
        }
        if newState == window.isFullscreenOverlay {
            io.err((newState ? "Already fullscreen. " : "Already not fullscreen. ") +
                "Tip: use --fail-if-noop to exit with non-zero code")
            return !args.failIfNoop
        }
        window.isFullscreenOverlay = newState
        window.noOuterGapsInFullscreenOverlay = args.noOuterGaps

        // Focus on its own workspace
        window.markAsMostRecentChild()
        return true
    }
}

package let noWindowIsFocused = "No window is focused"
