import AppKit
import Common
import Network

@MainActor
func startUnixSocketServer() {
    startUnixSocketServer(session: currentSession)
}

func startUnixSocketServer(session: AppSession) {
    try? FileManager.default.removeItem(atPath: socketPath)
    let params = NWParameters.tcp
    params.requiredLocalEndpoint = .unix(path: socketPath)
    let listener = Result { try NWListener(using: params) }.getOrDie()
    listener.newConnectionHandler = { connection in
        Task {
            defer { connection.cancel() }
            connection.start(queue: .global())
            await newConnection(session: session, connection)
        }
    }
    listener.start(queue: .global())
}

private let serverVersionAndHash = appVersionForDisplay

private func newConnection(session: AppSession, _ connection: NWConnection) async { // todo add exit codes
    func answerToClient(exitCode: Int32, stdout: String = "", stderr: String = "") async {
        let ans = ServerAnswer(exitCode: exitCode, stdout: stdout, stderr: stderr, serverVersionAndHash: serverVersionAndHash)
        await answerToClient(ans)
    }
    func answerToClient(_ ans: ServerAnswer) async {
        _ = await connection.write(ans)
    }
    while true {
        let (rawRequest, error) = await connection.read().getOrNils()
        if let error {
            await answerToClient(exitCode: 1, stderr: "Error: \(error)")
            return
        }
        // EOF / peer closed connection.
        guard let rawRequest else { return }
        let _request = ClientRequest.decodeJson(rawRequest)
        guard let request: ClientRequest = _request.getOrNil() else {
            await answerToClient(
                exitCode: 1,
                stderr: """
                    Can't parse request '\(String(describing: String(data: rawRequest, encoding: .utf8)).singleQuoted)'.
                    Error: \(_request.failureOrNil.prettyDescription)
                    """,
            )
            continue
        }
        switch parseCommand(request.args) {
            case .help(let help):
                await answerToClient(exitCode: 0, stdout: help)
                continue
            case .failure(let err):
                await answerToClient(exitCode: 1, stderr: err)
                continue
            case .cmd(let command):
                let _answer: Result<ServerAnswer, Error> = await Result {
                    try await session.runLightSession(.socketServer) { () throws in
                        let env = CmdEnv.init(
                            windowId: request.windowId,
                            workspaceName: request.workspace,
                        )
                        let cmdResult = try await [command].runCmdSeq(in: session, env, CmdStdin(request.stdin))
                        return ServerAnswer(
                            exitCode: cmdResult.exitCode,
                            stdout: cmdResult.stdout.joined(separator: "\n"),
                            stderr: cmdResult.stderr.joined(separator: "\n"),
                            serverVersionAndHash: serverVersionAndHash,
                        )
                    }
                }
                let answer = _answer.getOrNil() ??
                    ServerAnswer(
                        exitCode: 1,
                        stderr: "Fail to await main thread. \(_answer.failureOrNil?.localizedDescription ?? "")",
                        serverVersionAndHash: serverVersionAndHash,
                    )
                await answerToClient(answer)
                continue
        }
    }
}
