import Common
import Darwin
import Foundation
import Network

let usage =
    """
    USAGE: \(CommandLine.arguments.first ?? cliName) [-h|--help] [-v|--version] <subcommand> [<args>...]

    SUBCOMMANDS:
    \(subcommandDescriptions.sortedBy { $0[0] }.toPaddingTable(columnSeparator: "   ").joined(separator: "\n"))
    """

@main
struct Main {
    static func main() async {
        let args = CommandLine.arguments.slice(1...) ?? []

        if args.isEmpty {
            eprint(usage)
            exit(1)
        }
        if args.first == "--help" || args.first == "-h" {
            print(usage)
            exit(0)
        }

        if args.first == "--version" || args.first == "-v" {
            print(cliClientVersionAndHash)
            exit(0)
        }

        var parsedArgs: (any CmdArgs)! = nil
        switch parseCmdArgs(args) {
            case .cmd(let _parsedArgs):
                parsedArgs = _parsedArgs
            case .help(let help):
                print(help)
                exit(0)
            case .failure(let e):
                exit(stderrMsg: e)
        }

        if parsedArgs is DoctorCmdArgs {
            exit(await runDoctor())
        }

        let connection = NWConnection(to: NWEndpoint.unix(path: socketPath), using: .tcp)

        if let e = await connection.startBlocking() {
            exit(stderrMsg: "Can't connect to \(productName).app Daemon. Is \(productName) running?\n\(e.localizedDescription)")
        }

        var stdin = ""
        if (parsedArgs is WorkspaceCmdArgs && (parsedArgs as! WorkspaceCmdArgs).target.val.isRelative
            || parsedArgs is MoveNodeToWorkspaceCmdArgs && (parsedArgs as! MoveNodeToWorkspaceCmdArgs).target.val.isRelative)
            && hasStdin()
        {
            if parsedArgs is WorkspaceCmdArgs && (parsedArgs as! WorkspaceCmdArgs).explicitStdinFlag == nil ||
                parsedArgs is MoveNodeToWorkspaceCmdArgs && (parsedArgs as! MoveNodeToWorkspaceCmdArgs).explicitStdinFlag == nil
            {
                exit(
                    stderrMsg: """
                        ERROR: Implicit stdin is detected (stdin is not TTY).
                        1. Please supply '--stdin' flag to make stdin explicit
                        2. You can also use '--no-stdin' flag to behave as if no stdin was supplied
                        """,
                )
            }
            var index = 0
            while let line = readLine(strippingNewline: false) {
                stdin += line
                index += 1
                if index > 1000 {
                    exit(stderrMsg: "stdin number of lines limit is exceeded")
                }
            }
        }

        let windowId = ProcessInfo.processInfo.environment[FRAME_WINDOW_ID].flatMap(UInt32.init)
        let workspace = ProcessInfo.processInfo.environment[FRAME_WORKSPACE]
        let ans = await run(connection, args, stdin: stdin, windowId: windowId, workspace: workspace)

        if !ans.stdout.isEmpty { print(ans.stdout) }
        if !ans.stderr.isEmpty { eprint(ans.stderr) }
        exit(ans.exitCode)
    }
}

func runDoctor() async -> Int32 {
    let connection = NWConnection(to: NWEndpoint.unix(path: socketPath), using: .tcp)
    if await connection.startBlocking() != nil {
        print(
            VersionPresentation.doctorOutput(
                cliVersion: cliClientVersionAndHash,
                daemonVersion: nil,
                configHealthy: nil,
                configDetails: nil,
            ),
        )
        return VersionPresentation.doctorExitCode(cliVersion: cliClientVersionAndHash, daemonVersion: nil, configHealthy: nil)
    }
    let ans = await run(connection, ["doctor"], stdin: "", windowId: nil, workspace: nil)
    let configHealthy = ans.exitCode == 0
    let configDetails = [ans.stdout, ans.stderr]
        .filter { !$0.trim().isEmpty }
        .joined(separator: "\n")
    print(
        VersionPresentation.doctorOutput(
            cliVersion: cliClientVersionAndHash,
            daemonVersion: ans.serverVersionAndHash,
            configHealthy: configHealthy,
            configDetails: configDetails.isEmpty ? nil : configDetails,
        ),
    )
    return VersionPresentation.doctorExitCode(
        cliVersion: cliClientVersionAndHash,
        daemonVersion: ans.serverVersionAndHash,
        configHealthy: configHealthy,
    )
}

func run(_ connection: NWConnection, _ args: StrArrSlice, stdin: String, windowId: UInt32?, workspace: String?) async -> ServerAnswer {
    if let e = await connection.write(ClientRequest(args: args.toArray(), stdin: stdin, windowId: windowId, workspace: workspace)) {
        exit(stderrMsg: "Failed to write to daemon socket: \(e)")
    }

    switch await connection.read() {
        case .success(let answer):
            return (try? JSONDecoder().decode(ServerAnswer.self, from: answer)) ?? exitT(stderrMsg: "Failed to parse daemon response")
        case .failure(let error):
            exit(stderrMsg: "Failed to read from daemon socket: \(error)")
    }
}
