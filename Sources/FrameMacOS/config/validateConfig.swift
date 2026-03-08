import Foundation
import FrameEngine

func validateConfig(_ config: Config) -> [TomlParseError] {
    var errors: [TomlParseError] = []

    for (index, arg) in config.workspaceChangeHook.enumerated() {
        if arg.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            let backtrace = TomlBacktrace.rootKey("workspace-change-hook") + .index(index)
            errors.append(.semantic(backtrace, "Cannot be empty"))
        }
    }

    return errors
}
