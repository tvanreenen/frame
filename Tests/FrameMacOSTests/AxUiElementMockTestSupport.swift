@testable import FrameEngine
@testable import FrameMacOS
import AppKit
import Common

extension [String: Json]: AxUiElementMock {
    public func get<Attr>(_ attr: Attr) -> Attr.T? where Attr: ReadableAttr {
        guard let value = self[attr.key] else {
            return isSynthetic ? dieT("\(self) doesn't contain \(attr.key)") : nil
        }
        if let value = value.rawValue {
            return attr.getter(value as AnyObject)
                ?? dieT("Value \(value) (of type \(Swift.type(of: value))) isn't convertible to \(attr.key)")
        } else {
            return nil
        }
    }

    private var isSynthetic: Bool { self[kAXAeroSynthetic] != nil }

    public func containingWindowId() -> CGWindowID? {
        guard let rawWindowId = self["Aero.axWindowId"]?.rawValue else { return nil }
        if let windowId = rawWindowId as? UInt32 { return windowId }
        if let windowId = rawWindowId as? Int { return UInt32(windowId) }
        if let windowId = rawWindowId as? NSNumber { return windowId.uint32Value }
        if let windowId = rawWindowId as? String, let parsed = UInt32(windowId) { return parsed }
        return dieT("Unsupported Aero.axWindowId value \(rawWindowId) of type \(Swift.type(of: rawWindowId))")
    }
}

extension NSApplication.ActivationPolicy {
    static func from(string: String) -> NSApplication.ActivationPolicy {
        switch string {
            case "regular": .regular
            case "accessory": .accessory
            case "prohibited": .prohibited
            default: dieT("Unknown ActivationPolicy \(string)")
        }
    }
}
