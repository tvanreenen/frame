import AppKit
import Common

struct ListMonitorsCommand: Command {
    let args: ListMonitorsCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let focus = focus
        var result = sortedMonitors
        if let focused = args.focused {
            result = result.filter { (monitor) in (monitor.activeWorkspace == focus.workspace) == focused }
        }
        if let mouse = args.mouse {
            let mouseWorkspace = mouseLocation.monitorApproximation.activeWorkspace
            result = result.filter { (monitor) in (monitor.activeWorkspace == mouseWorkspace) == mouse }
        }

        if args.outputOnlyCount {
            return io.out("\(result.count)")
        } else {
            if args.json {
                return outputJson(result.map(ListMonitorsJsonRow.init), io)
            } else {
                let lines = result.map(ListMonitorsTextRow.init).map(\.columns).toPaddingTable()
                return io.out(lines)
            }
        }
    }
}

private struct ListMonitorsTextRow {
    let columns: [String]

    init(_ monitor: Monitor) {
        columns = [
            monitor.monitorId.map { "\($0 + 1)" } ?? "NULL-MONITOR-ID",
            monitor.name,
        ]
    }
}

private struct ListMonitorsJsonRow: Encodable {
    let monitorId: Int?
    let monitorName: String

    enum CodingKeys: String, CodingKey {
        case monitorId = "monitor-id"
        case monitorName = "monitor-name"
    }

    init(_ monitor: Monitor) {
        monitorId = monitor.monitorId.map { $0 + 1 }
        monitorName = monitor.name
    }
}
