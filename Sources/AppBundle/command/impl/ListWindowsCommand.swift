import AppKit
import Common

struct ListWindowsCommand: Command {
    let args: ListWindowsCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let focus = focus
        var windows: [Window] = []

        if args.filteringOptions.focused {
            if let window = focus.windowOrNil {
                windows = [window]
            } else {
                return io.err(noWindowIsFocused)
            }
        } else {
            var workspaces: Set<Workspace> = args.filteringOptions.workspaces.isEmpty
                ? Workspace.all.toSet()
                : args.filteringOptions.workspaces
                    .flatMap { filter in
                        switch filter {
                            case .focused: [focus.workspace]
                            case .visible: Workspace.all.filter(\.isVisible)
                            case .name(let name): [Workspace.get(byName: name.raw)]
                        }
                    }
                    .toSet()
            if !args.filteringOptions.monitors.isEmpty {
                let monitors: Set<CGPoint> = args.filteringOptions.monitors.resolveMonitors(io)
                if monitors.isEmpty { return false }
                workspaces = workspaces.filter { monitors.contains($0.workspaceMonitor.rect.topLeftCorner) }
            }
            windows = workspaces.flatMap(\.allLeafWindowsRecursive)
            if let pid = args.filteringOptions.pidFilter {
                windows = windows.filter { $0.app.pid == pid }
            }
            if let appId = args.filteringOptions.appIdFilter {
                windows = windows.filter { $0.app.rawAppBundleId == appId }
            }
        }

        if args.outputOnlyCount {
            return io.out("\(windows.count)")
        } else {
            var _list: [(window: Window, title: String)] = [] // todo cleanup
            for window in windows {
                _list.append((window, try await window.title))
            }
            _list = _list.filter { $0.window.isBound }
            _list = _list.sortedBy([{ $0.window.app.name ?? "" }, \.title])

            if args.json {
                return outputJson(_list.map(ListWindowsJsonRow.init), io)
            } else {
                let lines = _list.map(ListWindowsTextRow.init).map(\.columns).toPaddingTable()
                return io.out(lines)
            }
        }
    }
}

private struct ListWindowsTextRow {
    let columns: [String]

    init(_ item: (window: Window, title: String)) {
        columns = [
            item.window.windowId.description,
            item.window.app.name ?? "NULL-APP-NAME",
            item.title,
        ]
    }
}

private struct ListWindowsJsonRow: Encodable {
    let windowId: UInt32
    let appName: String
    let windowTitle: String

    enum CodingKeys: String, CodingKey {
        case windowId = "window-id"
        case appName = "app-name"
        case windowTitle = "window-title"
    }

    init(_ item: (window: Window, title: String)) {
        windowId = item.window.windowId
        appName = item.window.app.name ?? "NULL-APP-NAME"
        windowTitle = item.title
    }
}
