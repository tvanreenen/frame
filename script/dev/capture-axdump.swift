#!/usr/bin/swift

import AppKit
import ApplicationServices
import Foundation

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ out: UnsafeMutablePointer<CGWindowID>) -> AXError

private enum AxKind: Hashable {
    case button
    case window
    case app
}

private let globalIgnore: Set<String> = [
    "AXChildren", // too verbose
    "AXChildrenInNavigationOrder", // too verbose
    "AXFocusableAncestor", // infinite recursion
    kAXHelpAttribute as String, // localized
    kAXRoleDescriptionAttribute as String, // localized
]

private let kindSpecificIgnore: [AxKind: Set<String>] = [
    .button: [
        "AXFrame",
        kAXEditedAttribute as String,
        kAXFocusedAttribute as String,
        kAXPositionAttribute as String,
        kAXSizeAttribute as String,
    ],
    .app: [
        "AXEnhancedUserInterface",
        "AXPreferredLanguage",
        kAXHiddenAttribute as String,
    ],
]

private let priorityAx: Set<String> = [
    kAXTitleAttribute as String,
    kAXRoleAttribute as String,
    kAXSubroleAttribute as String,
    kAXIdentifierAttribute as String,
]

private struct Args {
    let output: URL
    let expectedType: String
    let expectedDialogHeuristic: Bool
    let overwrite: Bool
}

private func parseArgs() -> Args {
    let argv = CommandLine.arguments.dropFirst()
    var output: String?
    var expectedType: String?
    var expectedDialogHeuristic: Bool?
    var overwrite = false

    var i = argv.startIndex
    while i < argv.endIndex {
        let arg = argv[i]
        switch arg {
            case "--output":
                i = argv.index(after: i)
                guard i < argv.endIndex else { fail("--output requires a value") }
                output = argv[i]
            case "--expected-type":
                i = argv.index(after: i)
                guard i < argv.endIndex else { fail("--expected-type requires a value") }
                expectedType = argv[i]
            case "--expected-dialog-heuristic":
                i = argv.index(after: i)
                guard i < argv.endIndex else { fail("--expected-dialog-heuristic requires a value") }
                let value = argv[i]
                switch value {
                    case "true": expectedDialogHeuristic = true
                    case "false": expectedDialogHeuristic = false
                    default: fail("Expected 'true' or 'false' for --expected-dialog-heuristic, got '\(value)'")
                }
            case "--overwrite":
                overwrite = true
            case "-h", "--help":
                printUsageAndExit()
            default:
                fail("Unknown argument '\(arg)'")
        }
        i = argv.index(after: i)
    }

    guard let output else { fail("Missing required --output") }
    guard let expectedType else { fail("Missing required --expected-type") }
    guard ["window", "dialog", "popup"].contains(expectedType) else {
        fail("--expected-type must be one of: window, dialog, popup")
    }
    guard let expectedDialogHeuristic else { fail("Missing required --expected-dialog-heuristic") }

    return Args(
        output: URL(filePath: output),
        expectedType: expectedType,
        expectedDialogHeuristic: expectedDialogHeuristic,
        overwrite: overwrite,
    )
}

private func printUsageAndExit() -> Never {
    let script = URL(filePath: CommandLine.arguments.first ?? "capture-axdump.swift").lastPathComponent
    print("""
        Usage:
          swift script/dev/\(script) --output <path.json5> --expected-type <window|dialog|popup> --expected-dialog-heuristic <true|false> [--overwrite]

        Captures the focused window + app AX snapshot into a fixture file.
        """)
    Foundation.exit(0)
}

private func fail(_ message: String) -> Never {
    fputs("Error: \(message)\n", stderr)
    Foundation.exit(1)
}

private func axAttributeValue(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var raw: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key as CFString, &raw) == .success ? (raw as AnyObject?) : nil
}

private func axAttributeNames(_ element: AXUIElement, failed: inout [String]) -> [String] {
    var names: CFArray?
    if AXUIElementCopyAttributeNames(element, &names) != .success {
        failed.append("AXUIElementCopyAttributeNames")
    }
    return names as? [String] ?? []
}

private func containingWindowId(_ element: AXUIElement) -> UInt32? {
    var windowId = CGWindowID()
    return _AXUIElementGetWindow(element, &windowId) == .success ? windowId : nil
}

private func axStringAttr(_ element: AXUIElement, _ key: String) -> String? {
    axAttributeValue(element, key) as? String
}

private func prettyValue(_ value: Any?, recursionDepth: Int) -> Any {
    if recursionDepth > 5 {
        return [
            "dumpAxRecursive infinite recursion": true,
            "Aero.synthetic": true,
        ]
    }
    guard let value else { return NSNull() }

    if let value = value as? String { return value }
    if let value = value as? NSNumber { return value }
    if let value = value as? [Any] {
        return value.map { prettyValue($0, recursionDepth: recursionDepth) }
    }
    let anyObject = value as AnyObject
    if CFGetTypeID(anyObject) == AXValueGetTypeID() {
        let axValue = unsafeBitCast(anyObject, to: AXValue.self)
        return CFCopyDescription(axValue) as String? ?? String(describing: axValue)
    }
    if CFGetTypeID(anyObject) == AXUIElementGetTypeID() {
        let axElement = unsafeBitCast(anyObject, to: AXUIElement.self)
        if axStringAttr(axElement, kAXRoleAttribute as String) == kAXButtonRole as String {
            return dumpAxRecursive(axElement, .button, recursionDepth: recursionDepth)
        }
        if let windowId = containingWindowId(axElement) {
            let title = axStringAttr(axElement, kAXTitleAttribute as String) ?? "nil"
            let role = axStringAttr(axElement, kAXRoleAttribute as String) ?? "nil"
            let subrole = axStringAttr(axElement, kAXSubroleAttribute as String) ?? "nil"
            return "AXUIElement(AxWindowId=\(windowId), title=\(title.debugDescription), role=\(role.debugDescription), subrole=\(subrole.debugDescription))"
        }
        return String(describing: axElement)
    }
    return String(describing: value)
}

private func dumpAxRecursive(_ ax: AXUIElement, _ kind: AxKind, recursionDepth: Int = 0) -> [String: Any] {
    let recursionDepth = recursionDepth + 1
    var result: [String: Any] = [:]
    var ignored: [String] = []
    var writable: [String] = []
    var failedAxRequest: [String] = []

    let keys = axAttributeNames(ax, failed: &failedAxRequest).sorted {
        (priorityAx.contains($0) ? 0 : 1) < (priorityAx.contains($1) ? 0 : 1)
    }

    for key in keys {
        if globalIgnore.contains(key) || kindSpecificIgnore[kind]?.contains(key) == true {
            ignored.append(key)
            continue
        }

        let raw = axAttributeValue(ax, key)
        if raw == nil {
            failedAxRequest.append("get.\(key)")
        }
        result[key] = prettyValue(raw, recursionDepth: recursionDepth)

        var isWritable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(ax, key as CFString, &isWritable) != .success {
            failedAxRequest.append("isWritable.\(key)")
        }
        if isWritable.boolValue { writable.append(key) }
    }

    if !writable.isEmpty { result["Aero.AxWritable"] = writable.joined(separator: ", ") }
    if !failedAxRequest.isEmpty { result["Aero.AxFailed"] = failedAxRequest.joined(separator: ", ") }
    if !ignored.isEmpty { result["Aero.AxIgnored"] = ignored.joined(separator: ", ") }
    return result
}

private func activationPolicyString(_ app: NSRunningApplication) -> String {
    switch app.activationPolicy {
        case .regular: return "regular"
        case .accessory: return "accessory"
        case .prohibited: return "prohibited"
        @unknown default: return "prohibited"
    }
}

private func bundleString(_ bundle: Bundle?, _ key: String) -> String? {
    bundle?.infoDictionary?[key] as? String
}

private func main() throws {
    let args = parseArgs()
    if FileManager.default.fileExists(atPath: args.output.path) && !args.overwrite {
        fail("Output file already exists. Use --overwrite to replace it: \(args.output.path)")
    }

    if !AXIsProcessTrusted() {
        fail("Accessibility permission is required. Grant Terminal accessibility access in macOS settings.")
    }

    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
        fail("No frontmost app detected")
    }
    let axApp = AXUIElementCreateApplication(frontmostApp.processIdentifier)

    var focusedWindowRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
          let focusedWindowRef,
          CFGetTypeID(focusedWindowRef) == AXUIElementGetTypeID()
    else {
        fail("Could not read focused AX window for app pid \(frontmostApp.processIdentifier)")
    }
    let focusedWindow = unsafeBitCast(focusedWindowRef, to: AXUIElement.self)

    guard let windowId = containingWindowId(focusedWindow) else {
        fail("Focused AX element does not map to a window id")
    }

    let bundle = frontmostApp.bundleURL.flatMap { Bundle(url: $0) }
    var payload = dumpAxRecursive(focusedWindow, .window)
    payload["Aero.AXApp"] = dumpAxRecursive(axApp, .app)
    payload["Aero.App.appBundleId"] = frontmostApp.bundleIdentifier as Any
    payload["Aero.App.nsApp.activationPolicy"] = activationPolicyString(frontmostApp)
    payload["Aero.App.nsApp.execPath"] = frontmostApp.executableURL?.absoluteString as Any
    payload["Aero.App.version"] = bundleString(bundle, "CFBundleVersion") as Any
    payload["Aero.App.versionShort"] = bundleString(bundle, "CFBundleShortVersionString") as Any
    payload["Aero.AxUiElementWindowType"] = args.expectedType
    payload["Aero.AxUiElementWindowType_isDialogHeuristic"] = args.expectedDialogHeuristic
    payload["Aero.axWindowId"] = Int(windowId)
    payload["Aero.macOS.version"] = ProcessInfo.processInfo.operatingSystemVersionString

    let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    try FileManager.default.createDirectory(at: args.output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: args.output, options: .atomic)

    print("Wrote AX fixture to \(args.output.path)")
    print("Verify with: swift test --filter AxWindowKindTest")
}

do {
    try main()
} catch {
    fail(String(describing: error))
}
