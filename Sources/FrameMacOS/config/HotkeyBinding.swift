import AppKit
import Common
import FrameEngine
import Foundation
import HotKey
import TOMLKit

private struct HotkeyId: Equatable, Hashable {
    let modifiers: KeyModifiers
    let keyCode: UInt32

    static func == (lhs: HotkeyId, rhs: HotkeyId) -> Bool {
        lhs.modifiers.rawValue == rhs.modifiers.rawValue && lhs.keyCode == rhs.keyCode
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(modifiers.rawValue)
        hasher.combine(keyCode)
    }
}

@MainActor private var hotkeys: [HotkeyId: HotKey] = [:]

@MainActor func resetHotKeys() {
    // Explicitly unregister all hotkeys. We cannot always rely on destruction of the HotKey object to trigger
    // unregistration because we might be running inside a hotkey handler that is keeping its HotKey object alive.
    for (_, key) in hotkeys {
        key.isEnabled = false
    }
    hotkeys = [:]
}

extension HotKey {
    var isEnabled: Bool {
        get { !isPaused }
        set {
            if isEnabled != newValue {
                isPaused = !newValue
            }
        }
    }
}

@MainActor func syncHotKeys(session: AppSession = currentSession) {
    resetHotKeys()
    for binding in session.config.bindings.values {
        let hotkeyId = HotkeyId(modifiers: binding.modifiers, keyCode: binding.keyCode)
        hotkeys[hotkeyId] = HotKey(carbonKeyCode: binding.keyCode, carbonModifiers: binding.modifiers.carbonFlags, keyDownHandler: {
            Task {
                try await session.runLightSession(.hotkeyBinding) {
                    _ = try await binding.commands.runCmdSeq(in: session, .defaultEnv, .emptyStdin)
                }
            }
        })
        hotkeys[hotkeyId]?.isEnabled = true
    }
}

func parseBindings(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError], _ mapping: [String: Key]) -> [String: HotkeyBinding] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: HotkeyBinding] = [:]
    for (rawBinding, rawCommand): (String, TOMLValueConvertible) in rawTable {
        let backtrace = backtrace + .key(rawBinding)
        let binding = parseBinding(rawBinding, backtrace, mapping)
            .flatMap { modifiers, key -> ParsedToml<HotkeyBinding> in
                parseCommandOrCommands(rawCommand).toParsedToml(backtrace).map {
                    HotkeyBinding(
                        modifiers: modifiers,
                        keyCode: key.carbonKeyCode,
                        descriptionWithKeyCode: modifiers.isEmpty ? key.toString() : modifiers.toString() + "-" + key.toString(),
                        commands: $0,
                    )
                }
            }
            .getOrNil(appendErrorTo: &errors)
        if let binding {
            if result.keys.contains(binding.descriptionWithKeyCode) {
                errors.append(.semantic(backtrace, "'\(binding.descriptionWithKeyCode)' Binding redeclaration"))
            }
            result[binding.descriptionWithKeyCode] = binding
        }
    }
    return result
}

func parseBinding(_ raw: String, _ backtrace: TomlBacktrace, _ mapping: [String: Key]) -> ParsedToml<(KeyModifiers, Key)> {
    let rawKeys = raw.split(separator: "-")
    let modifiers: ParsedToml<KeyModifiers> = rawKeys.dropLast()
        .mapAllOrFailure {
            modifiersMap[String($0)].orFailure(.semantic(backtrace, "Can't parse modifiers in '\(raw)' binding"))
        }
        .map { $0.reduce(into: KeyModifiers()) { $0.formUnion($1) } }
    let key: ParsedToml<Key> = rawKeys.last.flatMap { mapping[String($0)] }
        .orFailure(.semantic(backtrace, "Can't parse the key in '\(raw)' binding"))
    return modifiers.flatMap { modifiers -> ParsedToml<(KeyModifiers, Key)> in
        key.flatMap { key -> ParsedToml<(KeyModifiers, Key)> in
            .success((modifiers, key))
        }
    }
}
