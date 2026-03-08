package final class CmdStdin {
    private var input: String = ""
    package init(_ input: String) {
        self.input = input
    }
    package static var emptyStdin: CmdStdin { .init("") }

    package func readAll() -> String {
        let result = input
        input = ""
        return result
    }
}

package final class CmdIo {
    private var stdin: CmdStdin
    package var stdout: [String] = []
    package var stderr: [String] = []

    package init(stdin: CmdStdin) { self.stdin = stdin }

    @discardableResult package func out(_ msg: String) -> Bool { stdout.append(msg); return true }
    @discardableResult package func err(_ msg: String) -> Bool { stderr.append(msg); return false }
    @discardableResult package func out(_ msg: [String]) -> Bool { stdout += msg; return true }
    @discardableResult package func err(_ msg: [String]) -> Bool { stderr += msg; return false }

    package func readStdin() -> String { stdin.readAll() }
}

package struct CmdResult {
    package let stdout: [String]
    package let stderr: [String]
    package let exitCode: Int32
}
