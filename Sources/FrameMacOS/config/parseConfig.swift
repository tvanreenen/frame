import AppKit
import Common
import FrameEngine
import HotKey
import TOMLKit

@MainActor
func readConfig(forceConfigUrl: URL? = nil) -> Result<(Config, URL), String> {
    let configUrl: URL
    if let forceConfigUrl {
        configUrl = forceConfigUrl
    } else {
        switch findCustomConfigUrl() {
            case .file(let url): configUrl = url
            case .noCustomConfigExists: configUrl = defaultConfigUrl
            case .ambiguousConfigError(let candidates):
                let msg = """
                    Ambiguous config error. Several configs found:
                    \(candidates.map(\.path).joined(separator: "\n"))
                    """
                return .failure(msg)
        }
    }
    let (parsedConfig, errors) = (try? String(contentsOf: configUrl, encoding: .utf8)).map { parseConfig($0) } ?? (defaultConfig, [])

    if errors.isEmpty {
        return .success((parsedConfig, configUrl))
    } else {
        return .failure(formatConfigErrors(configUrl: configUrl, errors: errors))
    }
}

package enum TomlParseError: Error, CustomStringConvertible, Equatable {
    case semantic(_ backtrace: TomlBacktrace, _ message: String)
    case syntax(_ message: String)

    package var description: String {
        return switch self {
            case .semantic(let backtrace, let message): backtrace.isEmptyRoot ? message : "\(backtrace): \(message)"
            case .syntax(let message): message
        }
    }
}

extension TomlParseError {
    var code: String {
        switch self {
            case .syntax:
                return "CFG000"
            case .semantic(_, let message) where message == "Unknown top-level key":
                return "CFG001"
            case .semantic(_, let message) where message == "Unknown key":
                return "CFG002"
            case .semantic(_, let message) where message.contains("Expected type is"):
                return "CFG003"
            case .semantic(_, let message) where message.contains("mandatory key"):
                return "CFG004"
            case .semantic(_, let message) where message.contains("Cannot be empty") || message.contains("Must contain at least one argument"):
                return "CFG005"
            case .semantic:
                return "CFG999"
        }
    }

    var groupKey: String {
        switch self {
            case .syntax:
                return "<syntax>"
            case .semantic(let backtrace, _):
                return backtrace.topLevelKey ?? "<root>"
        }
    }
}

typealias ParsedToml<T> = Result<T, TomlParseError>

extension ParserProtocol {
    func transformRawConfig(_ raw: S,
                            _ value: TOMLValueConvertible,
                            _ backtrace: TomlBacktrace,
                            _ errors: inout [TomlParseError]) -> S
    {
        if let value = parse(value, backtrace, &errors).getOrNil(appendErrorTo: &errors) {
            return raw.copy(keyPath, value)
        }
        return raw
    }
}

protocol ParserProtocol<S>: Sendable {
    associatedtype T
    associatedtype S where S: ConvenienceCopyable
    var keyPath: SendableWritableKeyPath<S, T> { get }
    var parse: @Sendable (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> ParsedToml<T> { get }
}

struct Parser<S: ConvenienceCopyable, T>: ParserProtocol {
    let keyPath: SendableWritableKeyPath<S, T>
    let parse: @Sendable (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> ParsedToml<T>

    init(_ keyPath: SendableWritableKeyPath<S, T>, _ parse: @escaping @Sendable (TOMLValueConvertible, TomlBacktrace, inout [TomlParseError]) -> T) {
        self.keyPath = keyPath
        self.parse = { raw, backtrace, errors -> ParsedToml<T> in .success(parse(raw, backtrace, &errors)) }
    }

    init(_ keyPath: SendableWritableKeyPath<S, T>, _ parse: @escaping @Sendable (TOMLValueConvertible, TomlBacktrace) -> ParsedToml<T>) {
        self.keyPath = keyPath
        self.parse = { raw, backtrace, _ -> ParsedToml<T> in parse(raw, backtrace) }
    }
}

private let keyMappingConfigRootKey = "key-mapping"
private let bindingConfigRootKey = "binding"
private let persistentWorkspacesKey = "persistent-workspaces"
private let configAllowedCmdKinds: Set<CmdKind> = [
    .addColumn,
    .balanceSizes,
    .focus,
    .focusMonitor,
    .fullscreen,
    .move,
    .moveMouse,
    .moveNodeToWorkspace,
    .reloadConfig,
    .removeColumn,
    .resize,
    .workspace,
]

private struct ParsedConfigScratch: ConvenienceCopyable {
    var startAtLogin: Bool = false
    var persistentWorkspaces: OrderedUniqueValues<String> = []
    var workspaceChangeHook: [String] = []
    var windowClassificationOverrides: [WindowClassificationOverride] = []
    var keyMapping = KeyMapping()
    var gaps: Gaps = .zero
    var workspaceToMonitorForceAssignment: [String: [MonitorDescription]] = [:]
    var bindings: [String: HotkeyBinding] = [:]

    var config: Config {
        var config = Config()
        config.startAtLogin = startAtLogin
        config.persistentWorkspaces = persistentWorkspaces
        config.workspaceChangeHook = workspaceChangeHook
        config.windowClassificationOverrides = windowClassificationOverrides
        config.gaps = gaps
        config.workspaceToMonitorForceAssignment = workspaceToMonitorForceAssignment
        config.bindings = bindings
        return config
    }
}

// For every new config option you add, think:
// 1. Does it make sense to have different value
// 2. Prefer commands and commands flags over toml options if possible
private let configParser: [String: any ParserProtocol<ParsedConfigScratch>] = [
    "start-at-login": Parser(\.startAtLogin, parseBool),
    persistentWorkspacesKey: Parser(\.persistentWorkspaces, parsePersistentWorkspaces),
    "workspace-change-hook": Parser(\.workspaceChangeHook, parseNonEmptyArrayOfStrings),
    "window-classification-override": Parser(\.windowClassificationOverrides, parseWindowClassificationOverrides),

    keyMappingConfigRootKey: Parser(\.keyMapping, skipParsing(KeyMapping())), // Parsed manually
    bindingConfigRootKey: Parser(\.bindings, skipParsing([:] as [String: HotkeyBinding])), // Parsed manually

    "gaps": Parser(\.gaps, parseGaps),
    "workspace-to-monitor-force-assignment": Parser(\.workspaceToMonitorForceAssignment, parseWorkspaceToMonitorAssignment),
]

extension ParsedCmd where T == any Command {
    fileprivate func toEither() -> Parsed<T> {
        return switch self {
            case .cmd(let a):
                configAllowedCmdKinds.contains(a.info.kind)
                    ? .success(a)
                    : .failure("Command '\(a.info.kind.rawValue)' cannot be used in config")
            case .help(let a): .failure(a)
            case .failure(let a): .failure(a)
        }
    }
}

func parseCommandOrCommands(_ raw: TOMLValueConvertible) -> Parsed<[any Command]> {
    if let rawString = raw.string {
        return parseCommand(rawString).toEither().map { [$0] }
    } else if let rawArray = raw.array {
        let commands: Parsed<[any Command]> = (0 ..< rawArray.count).mapAllOrFailure { index in
            let rawString: String = rawArray[index].string ?? expectedActualTypeError(expected: .string, actual: rawArray[index].type)
            return parseCommand(rawString).toEither()
        }
        return commands
    } else {
        return .failure(expectedActualTypeError(expected: [.string, .array], actual: raw.type))
    }
}

@MainActor func parseConfig(_ rawToml: String) -> (config: Config, errors: [TomlParseError]) { // todo change return value to Result
    let rawTable: TOMLTable
    do {
        rawTable = try TOMLTable(string: rawToml)
    } catch let e as TOMLParseError {
        return (defaultConfig, [.syntax(e.debugDescription)])
    } catch let e {
        return (defaultConfig, [.syntax(e.localizedDescription)])
    }

    var errors: [TomlParseError] = []

    var scratch = rawTable.parseTable(ParsedConfigScratch(), configParser, .emptyRoot, &errors)

    if let mapping = rawTable[keyMappingConfigRootKey].flatMap({ parseKeyMapping($0, .rootKey(keyMappingConfigRootKey), &errors) }) {
        scratch.keyMapping = mapping
    }

    // Parse bindingConfigRootKey after keyMappingConfigRootKey
    if let bindings = rawTable[bindingConfigRootKey].flatMap({ parseBindings($0, .rootKey(bindingConfigRootKey), &errors, scratch.keyMapping.resolve()) }) {
        scratch.bindings = bindings
    }

    let config = scratch.config
    errors += validateConfig(config)

    return (config, errors)
}

func parseInt(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Int> {
    raw.int.orFailure(expectedActualTypeError(expected: .int, actual: raw.type, backtrace))
}

func parseString(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<String> {
    raw.string.orFailure(expectedActualTypeError(expected: .string, actual: raw.type, backtrace))
}

func parseSimpleType<T>(_ raw: TOMLValueConvertible) -> T? {
    (raw.int as? T) ?? (raw.string as? T) ?? (raw.bool as? T)
}

extension TOMLValueConvertible {
    func unwrapTableWithSingleKey(expectedKey: String? = nil, _ backtrace: inout TomlBacktrace) -> ParsedToml<(key: String, value: TOMLValueConvertible)> {
        guard let table else {
            return .failure(expectedActualTypeError(expected: .table, actual: type, backtrace))
        }
        let singleKeyError: TomlParseError = .semantic(
            backtrace,
            expectedKey != nil
                ? "The table is expected to have a single key '\(expectedKey.orDie())'"
                : "The table is expected to have a single key",
        )
        guard let (actualKey, value): (String, TOMLValueConvertible) = table.count == 1 ? table.first : nil else {
            return .failure(singleKeyError)
        }
        if expectedKey != nil && expectedKey != actualKey {
            return .failure(singleKeyError)
        }
        backtrace = backtrace + .key(actualKey)
        return .success((actualKey, value))
    }
}

func parseTomlArray(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<TOMLArray> {
    raw.array.orFailure(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
}

func parseTable<T: ConvenienceCopyable>(
    _ raw: TOMLValueConvertible,
    _ initial: T,
    _ fieldsParser: [String: any ParserProtocol<T>],
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> T {
    guard let table = raw.table else {
        errors.append(expectedActualTypeError(expected: .table, actual: raw.type, backtrace))
        return initial
    }
    return table.parseTable(initial, fieldsParser, backtrace, &errors)
}

private func skipParsing<T: Sendable>(_ value: T) -> @Sendable (_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<T> {
    { _, _ in .success(value) }
}

private func parsePersistentWorkspaces(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<OrderedUniqueValues<String>> {
    parseArrayOfStrings(raw, backtrace)
        .flatMap { arr in
            OrderedUniqueValues(validatingUnique: arr)
                .map(Result.success)
                ?? .failure(.semantic(backtrace, "Contains duplicated workspace names"))
        }
}

private func parseArrayOfStrings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<[String]> {
    parseTomlArray(raw, backtrace)
        .flatMap { arr in
            arr.enumerated().mapAllOrFailure { (index, elem) in
                parseString(elem, backtrace + .index(index))
            }
        }
}

private func parseNonEmptyArrayOfStrings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<[String]> {
    parseArrayOfStrings(raw, backtrace).flatMap { parsed in
        parsed.isEmpty
            ? .failure(.semantic(backtrace, "Must contain at least one argument (executable path)"))
            : .success(parsed)
    }
}

extension Parsed where Failure == String {
    func toParsedToml(_ backtrace: TomlBacktrace) -> ParsedToml<Success> {
        mapError { .semantic(backtrace, $0) }
    }
}

func parseBool(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Bool> {
    raw.bool.orFailure(expectedActualTypeError(expected: .bool, actual: raw.type, backtrace))
}

package indirect enum TomlBacktrace: CustomStringConvertible, Equatable {
    case emptyRoot
    case rootKey(String)
    case key(String)
    case index(Int)
    case pair(TomlBacktrace, TomlBacktrace)

    package var description: String {
        return switch self {
            case .emptyRoot: "<root>"
            case .rootKey(let value): value
            case .key(let value): "." + value
            case .index(let index): "[\(index)]"
            case .pair(let first, let second): first.description + second.description
        }
    }

    var isEmptyRoot: Bool {
        return switch self {
            case .emptyRoot: true
            default: false
        }
    }

    var isRootKey: Bool {
        return switch self {
            case .rootKey: true
            default: false
        }
    }

    var topLevelKey: String? {
        switch self {
            case .rootKey(let value):
                return value
            case .pair(let first, let second):
                return first.topLevelKey ?? second.topLevelKey
            case .emptyRoot, .key, .index:
                return nil
        }
    }

    static func + (lhs: TomlBacktrace, rhs: TomlBacktrace) -> TomlBacktrace {
        if case .emptyRoot = lhs {
            if case .key(let newRoot) = rhs {
                return .rootKey(newRoot)
            } else {
                return rhs
            }
        } else {
            return pair(lhs, rhs)
        }
    }
}

extension TOMLTable {
    func parseTable<T: ConvenienceCopyable>(
        _ initial: T,
        _ fieldsParser: [String: any ParserProtocol<T>],
        _ backtrace: TomlBacktrace,
        _ errors: inout [TomlParseError],
    ) -> T {
        var raw = initial

        for (key, value) in self {
            let backtrace: TomlBacktrace = backtrace + .key(key)
            if let parser = fieldsParser[key] {
                raw = parser.transformRawConfig(raw, value, backtrace, &errors)
            } else {
                errors.append(unknownKeyError(backtrace))
            }
        }

        return raw
    }
}

func unknownKeyError(_ backtrace: TomlBacktrace) -> TomlParseError {
    .semantic(backtrace, backtrace.isRootKey ? "Unknown top-level key" : "Unknown key")
}

func expectedActualTypeError(expected: TOMLType, actual: TOMLType, _ backtrace: TomlBacktrace) -> TomlParseError {
    .semantic(backtrace, expectedActualTypeError(expected: expected, actual: actual))
}

func expectedActualTypeError(expected: [TOMLType], actual: TOMLType, _ backtrace: TomlBacktrace) -> TomlParseError {
    .semantic(backtrace, expectedActualTypeError(expected: expected, actual: actual))
}

func expectedActualTypeError(expected: TOMLType, actual: TOMLType) -> String {
    "Expected type is '\(expected)'. But actual type is '\(actual)'"
}

func expectedActualTypeError(expected: [TOMLType], actual: TOMLType) -> String {
    if let single = expected.singleOrNil() {
        return expectedActualTypeError(expected: single, actual: actual)
    } else {
        return "Expected types are \(expected.map { "'\($0.description)'" }.joined(separator: " or ")). But actual type is '\(actual)'"
    }
}

private func formatConfigErrors(configUrl: URL, errors: [TomlParseError]) -> String {
    let grouped = Dictionary(grouping: errors, by: \.groupKey)
    let formattedGroups = grouped
        .keys
        .sorted()
        .map { key -> String in
            let formattedErrors = grouped[key]!
                .map { "[\($0.code)] \($0.description)" }
                .joined(separator: "\n  - ")
            return """
                [\(key)]
                  - \(formattedErrors)
                """
        }
        .joined(separator: "\n\n")

    return """
        Failed to parse \(configUrl.absoluteURL.path)

        \(formattedGroups)

        Recovery:
        1. Fix the config and run '\(cliName) doctor'
        2. Apply with '\(cliName) reload-config'
        """
}
