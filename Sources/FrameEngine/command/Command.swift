import Common

package protocol Command: AeroAny, Equatable, Sendable {
    associatedtype T where T: CmdArgs
    var args: T { get }
    @MainActor
    func run(in session: AppSession, _ env: CmdEnv, _ io: CmdIo) async throws -> Bool

    /// We should reset closedWindowsCache when the command can potentiall change the tree
    var shouldResetClosedWindowsCache: Bool { get }
}

extension Command {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.args.equals(rhs.args)
    }

    nonisolated func equals(_ other: any Command) -> Bool {
        (other as? Self).flatMap { self == $0 } ?? false
    }
}

extension Command {
    @MainActor package func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        try await run(in: currentSession, env, io)
    }
}

extension Command {
    package var info: CmdStaticInfo { T.info }
}

extension Command {
    @MainActor @discardableResult package func run(_ env: CmdEnv, _ stdin: CmdStdin) async throws -> CmdResult {
        return try await [self].runCmdSeq(in: currentSession, env, stdin)
    }
}

// There are 3 entry points for running commands:
// 1. config keybindings
// 2. CLI requests to server
// 3. Tray icon buttons
extension [any Command] {
    package var prettyDescription: String {
        map { $0.args.description }.joined(separator: "; ")
    }

    @MainActor package func runCmdSeq(in session: AppSession, _ env: CmdEnv, _ io: sending CmdIo) async throws -> Bool {
        try await session.runAsCurrentSession {
            var isSucc = true
            for command in self {
                isSucc = try await command.run(in: session, env, io) && isSucc
                if command.shouldResetClosedWindowsCache { resetClosedWindowsCache() }
                refreshModel()
            }
            return isSucc
        }
    }

    @MainActor package func runCmdSeq(_ env: CmdEnv, _ io: sending CmdIo) async throws -> Bool {
        try await runCmdSeq(in: currentSession, env, io)
    }

    @MainActor package func runCmdSeq(in session: AppSession, _ env: CmdEnv, _ stdin: CmdStdin) async throws -> CmdResult {
        let io: CmdIo = CmdIo(stdin: stdin)
        let isSucc = try await runCmdSeq(in: session, env, io)
        return CmdResult(stdout: io.stdout, stderr: io.stderr, exitCode: isSucc ? 0 : 1)
    }

    @MainActor package func runCmdSeq(_ env: CmdEnv, _ stdin: CmdStdin) async throws -> CmdResult {
        try await runCmdSeq(in: currentSession, env, stdin)
    }
}
