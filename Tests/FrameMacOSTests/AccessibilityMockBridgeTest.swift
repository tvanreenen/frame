@testable import FrameEngine
@testable import FrameMacOS
import FrameTestSupport
import XCTest

final class AccessibilityMockBridgeTest: XCTestCase {
    func testAxWindowsResolvesSyntheticJsonArray() {
        let windowId: UInt32 = 37352
        let axApp: [String: Json] = [
            "AXWindows": .array([
                .dict([
                    "Aero.axWindowId": .uint32(windowId),
                    "AXRole": .string(kAXWindowRole),
                    "AXSubrole": .string(kAXStandardWindowSubrole),
                    "AXTitle": .string("Deck"),
                ]),
            ]),
        ]

        let windows = axApp.get(Ax.windowsAttr)

        assertEquals(windows?.count, 1)
        assertEquals(windows?.first?.windowId, windowId)
    }

    func testAxWindowsFiltersNonWindowEntriesInSyntheticJsonArray() {
        let windowId: UInt32 = 37352
        let axApp: [String: Json] = [
            "AXWindows": .array([
                .dict([
                    "AXRole": .string(kAXApplicationRole),
                ]),
                .dict([
                    "Aero.axWindowId": .uint32(windowId),
                    "AXRole": .string(kAXWindowRole),
                    "AXSubrole": .string(kAXStandardWindowSubrole),
                ]),
            ]),
        ]

        let windows = axApp.get(Ax.windowsAttr)

        assertEquals(windows?.count, 1)
        assertEquals(windows?.first?.windowId, windowId)
    }

    func testFocusedAndMainWindowMocksResolveSyntheticDictionaries() {
        let focusedWindowId: UInt32 = 37352
        let mainWindowId: UInt32 = 36873
        let axApp: [String: Json] = [
            "AXFocusedWindow": .dict([
                "Aero.axWindowId": .uint32(focusedWindowId),
                "AXRole": .string(kAXWindowRole),
                "AXSubrole": .string("AXUnknown"),
                "AXTitle": .string(""),
            ]),
            "AXMainWindow": .dict([
                "Aero.axWindowId": .uint32(mainWindowId),
                "AXRole": .string(kAXWindowRole),
                "AXSubrole": .string(kAXStandardWindowSubrole),
                "AXTitle": .string("Deck"),
            ]),
        ]

        assertEquals(axApp.get(Ax.focusedWindowAttr)?.windowId, focusedWindowId)
        assertEquals(axApp.get(Ax.mainWindowAttr)?.windowId, mainWindowId)
    }
}
