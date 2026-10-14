import AppKit

extension NSRunningApplication {
    func resolveAccessibilityProcessIdentifier(
        windowOwnerPids: @autoclosure () -> [pid_t] = windowOwnerProcessIdentifiers(),
    ) -> pid_t? {
        guard !isTerminated else { return nil }
        let pid = processIdentifier
        if pid > 0 { return pid }
        guard pid == -1 else { return nil }

        // Some apps (e.g. Device Hub) have a WindowServer PID that AppKit
        // does not expose. Match application identity, never window titles.
        let matches = Set(windowOwnerPids()).filter { candidatePid in
            guard candidatePid > 0,
                  let candidate = NSRunningApplication(processIdentifier: candidatePid),
                  !candidate.isTerminated
            else { return false }
            return isEqual(candidate)
        }
        guard matches.count == 1 else { return nil }
        return matches.first
    }

    var idForDebug: String {
        "PID: \(processIdentifier) ID: \(bundleIdentifier ?? executableURL?.description ?? "")"
    }
}

private func windowOwnerProcessIdentifiers() -> [pid_t] {
    let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
    let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    return windows.compactMap { $0[kCGWindowOwnerPID as String] as? pid_t }
}
