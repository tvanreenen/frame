import Common
import Darwin
import Foundation

let cliClientVersionAndHash: String = appVersionForDisplay

func hasStdin() -> Bool {
    isatty(STDIN_FILENO) != 1
}
