import AppKit
import Common
import Foundation

package struct HotkeyBinding: Equatable, Sendable {
    package let modifiers: NSEvent.ModifierFlags
    package let keyCode: UInt32
    package let commands: [any Command]
    package let descriptionWithKeyCode: String

    package init(modifiers: NSEvent.ModifierFlags, keyCode: UInt32, descriptionWithKeyCode: String, commands: [any Command]) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.commands = commands
        self.descriptionWithKeyCode = descriptionWithKeyCode
    }

    package static func == (lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        lhs.modifiers == rhs.modifiers &&
            lhs.keyCode == rhs.keyCode &&
            lhs.descriptionWithKeyCode == rhs.descriptionWithKeyCode &&
            zip(lhs.commands, rhs.commands).allSatisfy { $0.equals($1) }
    }
}

package struct PerMonitorValue<Value: Equatable>: Equatable {
    package let description: MonitorDescription
    package let value: Value
    package init(description: MonitorDescription, value: Value) {
        self.description = description
        self.value = value
    }
}
extension PerMonitorValue: Sendable where Value: Sendable {}

package enum DynamicConfigValue<Value: Equatable>: Equatable {
    case constant(Value)
    case perMonitor([PerMonitorValue<Value>], default: Value)
}
extension DynamicConfigValue: Sendable where Value: Sendable {}

extension DynamicConfigValue {
    package func getValue(for monitor: any Monitor) -> Value {
        switch self {
            case .constant(let value):
                return value
            case .perMonitor(let array, let defaultValue):
                let sortedMonitors = sortedMonitors
                return array
                    .lazy
                    .compactMap {
                        $0.description.resolveMonitor(sortedMonitors: sortedMonitors)?.rect.topLeftCorner == monitor.rect.topLeftCorner
                            ? $0.value
                            : nil
                    }
                    .first ?? defaultValue
        }
    }
}

package struct Gaps: ConvenienceCopyable, Equatable, Sendable {
    package var inner: Inner
    package var outer: Outer

    package static let zero = Gaps(inner: .zero, outer: .zero)

    package struct Inner: ConvenienceCopyable, Equatable, Sendable {
        package var vertical: DynamicConfigValue<Int>
        package var horizontal: DynamicConfigValue<Int>

        package static let zero = Inner(vertical: 0, horizontal: 0)

        package init(vertical: Int, horizontal: Int) {
            self.vertical = .constant(vertical)
            self.horizontal = .constant(horizontal)
        }

        package init(vertical: DynamicConfigValue<Int>, horizontal: DynamicConfigValue<Int>) {
            self.vertical = vertical
            self.horizontal = horizontal
        }
    }

    package struct Outer: ConvenienceCopyable, Equatable, Sendable {
        package var left: DynamicConfigValue<Int>
        package var bottom: DynamicConfigValue<Int>
        package var top: DynamicConfigValue<Int>
        package var right: DynamicConfigValue<Int>

        package static let zero = Outer(left: 0, bottom: 0, top: 0, right: 0)

        package init(left: Int, bottom: Int, top: Int, right: Int) {
            self.left = .constant(left)
            self.bottom = .constant(bottom)
            self.top = .constant(top)
            self.right = .constant(right)
        }

        package init(left: DynamicConfigValue<Int>, bottom: DynamicConfigValue<Int>, top: DynamicConfigValue<Int>, right: DynamicConfigValue<Int>) {
            self.left = left
            self.bottom = bottom
            self.top = top
            self.right = right
        }
    }
}

package struct ResolvedGaps {
    package let inner: Inner
    package let outer: Outer

    package struct Inner {
        package let vertical: Int
        package let horizontal: Int

        package func get(_ orientation: Orientation) -> Int {
            orientation == .h ? horizontal : vertical
        }
    }

    package struct Outer {
        package let left: Int
        package let bottom: Int
        package let top: Int
        package let right: Int
    }

    package init(gaps: Gaps, monitor: any Monitor) {
        inner = .init(
            vertical: gaps.inner.vertical.getValue(for: monitor),
            horizontal: gaps.inner.horizontal.getValue(for: monitor),
        )

        outer = .init(
            left: gaps.outer.left.getValue(for: monitor),
            bottom: gaps.outer.bottom.getValue(for: monitor),
            top: gaps.outer.top.getValue(for: monitor),
            right: gaps.outer.right.getValue(for: monitor),
        )
    }
}

package struct WindowClassificationOverride: ConvenienceCopyable, Equatable {
    package var matcher = WindowClassificationOverrideMatcher()
    package var kind: AxUiElementWindowType? = nil
    package init() {}

    package var resolvedKind: AxUiElementWindowType {
        kind ?? dieT("ID-DDD9B91A kind must be initialized by parser")
    }
}

package struct WindowClassificationOverrideMatcher: ConvenienceCopyable, Equatable {
    package var appId: String?
    package var appNameRegexSubstring: CaseInsensitiveRegexPattern?
    package var windowTitleRegexSubstring: CaseInsensitiveRegexPattern?
    package init() {}

    package var isEmpty: Bool {
        appId == nil &&
            appNameRegexSubstring == nil &&
            windowTitleRegexSubstring == nil
    }

    package func matches(appBundleId: String?, appName: String?, windowTitle: String?) -> Bool {
        if let appId, appId != appBundleId {
            return false
        }
        if let appNameRegexSubstring, !(appName?.contains(appNameRegexSubstring.regex) == true) {
            return false
        }
        if let windowTitleRegexSubstring, !(windowTitle?.contains(windowTitleRegexSubstring.regex) == true) {
            return false
        }
        return true
    }
}

package struct CaseInsensitiveRegexPattern: Equatable {
    package let raw: String
    package let regex: Regex<AnyRegexOutput>
    package init(raw: String, regex: Regex<AnyRegexOutput>) {
        self.raw = raw
        self.regex = regex
    }

    package static func == (lhs: CaseInsensitiveRegexPattern, rhs: CaseInsensitiveRegexPattern) -> Bool {
        lhs.raw == rhs.raw
    }
}

package struct Config: ConvenienceCopyable {
    package var startAtLogin: Bool = false
    package var persistentWorkspaces: OrderedUniqueValues<String> = []
    package var workspaceChangeHook: [String] = []
    package var windowClassificationOverrides: [WindowClassificationOverride] = []
    package var gaps: Gaps = .zero
    package var workspaceToMonitorForceAssignment: [String: [MonitorDescription]] = [:]
    package var bindings: [String: HotkeyBinding] = [:]
    package init() {}
}

@MainActor package var currentSession = AppSession(config: Config(), configUrl: URL(filePath: "/"))
@MainActor package var runtimeContext: AppSession { currentSession }
