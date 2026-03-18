import AppKit
import Common
import FrameEngine

struct ListAppsCommand: Command {
    let args: ListAppsCmdArgs

    func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) -> Bool {
        var result = session.registeredMacApps
        if let hidden = args.macosHidden {
            result = result.filter { $0.nsApp.isHidden == hidden }
        }

        if args.outputOnlyCount {
            return io.out("\(result.count)")
        } else {
            if args.json {
                return outputJson(result.map(ListAppsJsonRow.init), io)
            } else {
                let lines = result.map(ListAppsTextRow.init).map(\.columns).toPaddingTable()
                return io.out(lines)
            }
        }
    }
}

private struct ListAppsTextRow {
    let columns: [String]

    init(_ app: any WindowPlatformApp) {
        columns = [
            app.pid.description,
            app.rawAppBundleId ?? "NULL-APP-BUNDLE-ID",
            app.name ?? "NULL-APP-NAME",
        ]
    }
}

private struct ListAppsJsonRow: Encodable {
    let appPid: Int32
    let appBundleId: String
    let appName: String

    enum CodingKeys: String, CodingKey {
        case appPid = "app-pid"
        case appBundleId = "app-bundle-id"
        case appName = "app-name"
    }

    init(_ app: any WindowPlatformApp) {
        appPid = app.pid
        appBundleId = app.rawAppBundleId ?? "NULL-APP-BUNDLE-ID"
        appName = app.name ?? "NULL-APP-NAME"
    }
}
