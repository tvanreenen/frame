@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import XCTest
import FrameTestSupport

final class AxWindowKindTest: XCTestCase {
    func test() throws {
        try checkAxDumpsRecursive(projectRoot.appending(path: "Tests/FrameMacOSTests/fixtures/axDumps"))
    }

    func testPowerPointSecondaryButtonlessFocusedWindowIsPopup() {
        let popupWindowId: UInt32 = 37352
        let mainWindowId: UInt32 = 36873
        let axApp: [String: Json] = [
            "AXFocusedWindow": .string("AXUIElement(AxWindowId=\(popupWindowId), title=\"\", role=\"AXWindow\", subrole=\"AXUnknown\")"),
            "AXMainWindow": .string("AXUIElement(AxWindowId=\(mainWindowId), title=\"Deck\", role=\"AXWindow\", subrole=\"AXStandardWindow\")"),
        ]
        let popupWindow: [String: Json] = [
            "Aero.axWindowId": .uint32(popupWindowId),
            "AXCloseButton": .null,
            "AXFocused": .bool(true),
            "AXFullScreenButton": .null,
            "AXMain": .bool(false),
            "AXMinimizeButton": .null,
            "AXSubrole": .string("AXUnknown"),
            "AXTitle": .string(""),
            "AXZoomButton": .null,
        ]

        assertEquals(
            popupWindow.getWindowType(
                axApp: axApp,
                .powerPoint,
                .regular,
                .normalWindow,
            ),
            .popup,
        )
    }
}

func checkAxDumpsRecursive(_ dir: URL) throws {
    for file in try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
        if file.isDirectory {
            try checkAxDumpsRecursive(file)
            continue
        }
        if file.pathExtension == "md" { continue }

        let rawJson = try JSONSerialization.jsonObject(with: Data.init(contentsOf: file), options: [.json5Allowed]) as! [String: Any]
        try assertAxDumpSchema(rawJson, file)
        let json = Json.newOrDie(rawJson).asDictOrDie
        let app = json["Aero.AXApp"]!.asDictOrDie
        let appBundleId = (rawJson["Aero.App.appBundleId"] as? String).flatMap { KnownBundleId.init(rawValue: $0) }
        let windowLevel = json["Aero.windowLevel"].map { MacOsWindowLevel.fromJson($0) ?? dieT() }
        let activationPolicy: NSApplication.ActivationPolicy = .from(string: rawJson["Aero.App.nsApp.activationPolicy"] as! String)
        assertEquals(
            json.getWindowType(axApp: app, appBundleId, activationPolicy, windowLevel),
            AxUiElementWindowType(rawValue: rawJson["Aero.AxUiElementWindowType"] as? String ?? dieT()),
            additionalMsg: "\(file.path()):0:0: AxUiElementWindowType doesn't match",
        )
        assertEquals(
            json.isDialogHeuristic(appBundleId, windowLevel),
            rawJson["Aero.AxUiElementWindowType_isDialogHeuristic"] as? Bool ?? dieT(),
            additionalMsg: "\(file.path()):0:0: AxUiElementWindowType_isDialogHeuristic doesn't match",
        )
    }
}

private func assertAxDumpSchema(_ rawJson: [String: Any], _ file: URL) throws {
    let requiredKeys = [
        "Aero.AXApp",
        "Aero.App.nsApp.activationPolicy",
        "Aero.AxUiElementWindowType",
        "Aero.AxUiElementWindowType_isDialogHeuristic",
    ]
    for key in requiredKeys where rawJson[key] == nil {
        throw NSError(
            domain: "AxWindowKindTest",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "\(file.path):0:0: Missing required fixture key '\(key)'"],
        )
    }
    if rawJson["Aero.on-window-detected"] != nil {
        throw NSError(
            domain: "AxWindowKindTest",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "\(file.path):0:0: Legacy key 'Aero.on-window-detected' is no longer allowed"],
        )
    }
}

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
