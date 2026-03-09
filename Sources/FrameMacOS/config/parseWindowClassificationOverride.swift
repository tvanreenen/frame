import Common
import FrameEngine
import TOMLKit

private let windowClassificationOverrideParsers: [String: any ParserProtocol<WindowClassificationOverride>] = [
    "if": Parser(\.matcher, parseWindowClassificationOverrideMatcher),
    "kind": Parser(\.kind, upcast(parseWindowClassificationOverrideKind)),
]

private let windowClassificationOverrideMatcherParsers: [String: any ParserProtocol<WindowClassificationOverrideMatcher>] = [
    "app-id": Parser(\.appId, upcast(parseString)),
    "app-name-regex-substring": Parser(\.appNameRegexSubstring, upcast(parseCaseInsensitiveRegexPattern)),
    "window-title-regex-substring": Parser(\.windowTitleRegexSubstring, upcast(parseCaseInsensitiveRegexPattern)),
]

func parseWindowClassificationOverrides(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [WindowClassificationOverride] {
    guard let array = raw.array else {
        errors += [expectedActualTypeError(expected: .array, actual: raw.type, backtrace)]
        return []
    }
    return array.enumerated().compactMap { (index, elem) in
        parseWindowClassificationOverride(elem, backtrace + .index(index), &errors)
    }
}

private func parseWindowClassificationOverride(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> WindowClassificationOverride? {
    var localErrors: [TomlParseError] = []
    let parsed = parseTable(raw, WindowClassificationOverride(), windowClassificationOverrideParsers, backtrace, &localErrors)

    if parsed.kind == nil {
        localErrors.append(.semantic(backtrace, "'kind' is mandatory key"))
    }
    if parsed.matcher.isEmpty {
        localErrors.append(.semantic(backtrace, "'if' must include at least one matcher key"))
    }

    if !localErrors.isEmpty {
        errors += localErrors
        return nil
    }
    return parsed
}

private func parseWindowClassificationOverrideMatcher(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError]
) -> WindowClassificationOverrideMatcher {
    parseTable(raw, WindowClassificationOverrideMatcher(), windowClassificationOverrideMatcherParsers, backtrace, &errors)
}

private func parseWindowClassificationOverrideKind(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<WindowPlacementKind> {
    parseString(raw, backtrace).flatMap {
        switch $0 {
            case "tiling": .success(.tiling)
            case "excluded": .success(.excluded)
            default: .failure(.semantic(backtrace, "'kind' must be one of: tiling, excluded"))
        }
    }
}

private func parseCaseInsensitiveRegexPattern(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<CaseInsensitiveRegexPattern> {
    parseString(raw, backtrace)
        .flatMap { pattern in
            parseCaseInsensitiveRegex(pattern)
                .map { CaseInsensitiveRegexPattern(raw: pattern, regex: $0) }
                .toParsedToml(backtrace)
        }
}

private func upcast<T>(_ parse: @escaping @Sendable (TOMLValueConvertible, TomlBacktrace) -> ParsedToml<T>) -> @Sendable (TOMLValueConvertible, TomlBacktrace) -> ParsedToml<T?> {
    { parse($0, $1).map { $0 } }
}
