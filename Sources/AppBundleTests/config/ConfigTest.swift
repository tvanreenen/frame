@testable import AppBundle
import Common
import Foundation
import XCTest

@MainActor
final class ConfigTest: XCTestCase {
    func testParseDefaultConfig() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/default-config.toml"), encoding: .utf8)
        let (_, errors) = parseConfig(toml)
        assertEquals(errors, [])
    }

    func testDuplicatedPersistentWorkspaces() {
        let (_, errors) = parseConfig(
            """
            persistent-workspaces = ['a', 'a']
            """,
        )
        assertEquals(errors.descriptions, ["persistent-workspaces: Contains duplicated workspace names"])
    }

    func testQueryCantBeUsedInConfig() {
        let (_, errors) = parseConfig(
            """
            [binding]
                alt-a = 'list-apps'
            """,
        )
        XCTAssertTrue(errors.descriptions.singleOrNil()?.contains("cannot be used in config") == true)
    }

    func testDropBindings() {
        let (config, errors) = parseConfig(
            """
            [binding]
            """,
        )
        assertEquals(errors, [])
        XCTAssertTrue(config.bindings.isEmpty == true)
    }

    func testParseBindings() {
        let (config, errors) = parseConfig(
            """
            [binding]
                alt-h = 'focus left'
            """,
        )
        assertEquals(errors, [])
        let binding = HotkeyBinding(.option, .h, [FocusCommand.new(direction: .left)])
        assertEquals(config.bindings, [binding.descriptionWithKeyCode: binding])
    }

    func testHotkeyParseError() {
        let (config, errors) = parseConfig(
            """
            [binding]
                alt-hh = 'focus left'
                aalt-j = 'focus down'
                alt-k = 'focus up'
            """,
        )
        assertEquals(
            errors.descriptions,
            [
                "binding.aalt-j: Can\'t parse modifiers in \'aalt-j\' binding",
                "binding.alt-hh: Can\'t parse the key in \'alt-hh\' binding",
            ],
        )
        let binding = HotkeyBinding(.option, .k, [FocusCommand.new(direction: .up)])
        assertEquals(config.bindings, [binding.descriptionWithKeyCode: binding])
    }

    func testPersistentWorkspaces() {
        let (config, errors) = parseConfig(
            """
            persistent-workspaces = ['1', '2', '3', '4']
            [binding]
                alt-1 = 'workspace 1'
            """,
        )
        assertEquals(errors.descriptions, [])
        assertEquals(config.persistentWorkspaces.sorted(), ["1", "2", "3", "4"])
    }

    func testParseWorkspaceChangeHook() {
        let (config, errors) = parseConfig(
            """
            workspace-change-hook = ['/bin/bash', '-c', 'echo changed']
            """,
        )
        assertEquals(errors.descriptions, [])
        assertEquals(config.workspaceChangeHook, ["/bin/bash", "-c", "echo changed"])
    }

    func testWorkspaceChangeHookMustNotBeEmpty() {
        let (_, errors) = parseConfig(
            """
            workspace-change-hook = []
            """,
        )
        assertEquals(
            errors.descriptions,
            ["workspace-change-hook: Must contain at least one argument (executable path)"],
        )
    }

    func testWorkspaceChangeHookArgsMustNotBeBlank() {
        let (_, errors) = parseConfig(
            """
            workspace-change-hook = ['/bin/bash', '   ', 'echo changed']
            """,
        )
        assertEquals(
            errors.descriptions,
            ["workspace-change-hook[1]: Cannot be empty"],
        )
    }

    func testReadConfigFormatsErrorsWithCodesAndRecovery() throws {
        let configUrl = FileManager.default.temporaryDirectory
            .appendingPathComponent("frame-config-\(UUID().uuidString).toml")
        defer { try? FileManager.default.removeItem(at: configUrl) }
        try """
        unknownKey = true
        workspace-change-hook = ['/bin/bash', '   ']
        """.write(to: configUrl, atomically: true, encoding: .utf8)

        guard case let .failure(message) = readConfig(forceConfigUrl: configUrl) else {
            XCTFail("Expected readConfig to fail")
            return
        }

        XCTAssertTrue(message.contains("Failed to parse \(configUrl.path)"), message)
        XCTAssertTrue(message.contains("[unknownKey]"), message)
        XCTAssertTrue(message.contains("[workspace-change-hook]"), message)
        XCTAssertTrue(message.contains("[CFG001] unknownKey: Unknown top-level key"), message)
        XCTAssertTrue(message.contains("[CFG005] workspace-change-hook[1]: Cannot be empty"), message)
        XCTAssertTrue(message.contains("frame doctor"), message)
        XCTAssertTrue(message.contains("frame reload-config"), message)
    }

    func testParseWindowClassificationOverrides() {
        let (config, errors) = parseConfig(
            """
            [[window-classification-override]]
                if.app-id = 'com.apple.finder'
                kind = 'popup'

            [[window-classification-override]]
                if.window-title-regex-substring = 'picture-in-picture'
                kind = 'window'
            """,
        )
        assertEquals(errors.descriptions, [])
        assertEquals(config.windowClassificationOverrides.map(\.resolvedKind), [.popup, .window])
        XCTAssertTrue(
            config.windowClassificationOverrides[0].matcher.matches(
                appBundleId: "com.apple.finder",
                appName: nil,
                windowTitle: nil,
            ),
        )
        XCTAssertTrue(
            config.windowClassificationOverrides[1].matcher.matches(
                appBundleId: nil,
                appName: nil,
                windowTitle: "Picture-In-Picture",
            ),
        )
    }

    func testWindowClassificationOverrideValidationErrors() {
        let (_, errors) = parseConfig(
            """
            [[window-classification-override]]
                if.app-id = 'com.apple.finder'

            [[window-classification-override]]
                kind = 'window'
            """,
        )
        assertEquals(errors.descriptions, [
            "window-classification-override[0]: 'kind' is mandatory key",
            "window-classification-override[1]: 'if' must include at least one matcher key",
        ])
    }

    func testUnknownTopLevelKeyParseError() {
        let (config, errors) = parseConfig(
            """
            unknownKey = true
            start-at-login = true
            """,
        )
        assertEquals(
            errors.descriptions,
            ["unknownKey: Unknown top-level key"],
        )
        assertEquals(config.startAtLogin, true)
    }

    func testOnFocusedMonitorChangedIsUnknownTopLevelKey() {
        let (_, errors) = parseConfig(
            """
            on-focused-monitor-changed = ['move-mouse monitor-lazy-center']
            """,
        )
        assertEquals(
            errors.descriptions,
            ["on-focused-monitor-changed: Unknown top-level key"],
        )
    }

    func testAfterStartupCommandIsUnknownTopLevelKey() {
        let (_, errors) = parseConfig(
            """
            after-startup-command = ['focus left']
            """,
        )
        assertEquals(
            errors.descriptions,
            ["after-startup-command: Unknown top-level key"],
        )
    }

    func testOnFocusChangedIsUnknownTopLevelKey() {
        let (_, errors) = parseConfig(
            """
            on-focus-changed = ['focus left']
            """,
        )
        assertEquals(
            errors.descriptions,
            ["on-focus-changed: Unknown top-level key"],
        )
    }

    func testOnWindowDetectedIsUnknownTopLevelKey() {
        let (_, errors) = parseConfig(
            """
            [[on-window-detected]]
                run = ['focus left']
            """,
        )
        assertEquals(
            errors.descriptions,
            ["on-window-detected: Unknown top-level key"],
        )
    }

    func testExecOnWorkspaceChangeIsUnknownTopLevelKey() {
        let (_, errors) = parseConfig(
            """
            exec-on-workspace-change = ['/bin/bash', '-c', 'echo changed']
            """,
        )
        assertEquals(
            errors.descriptions,
            ["exec-on-workspace-change: Unknown top-level key"],
        )
    }

    func testExecConfigBlockIsUnknownTopLevelKey() {
        let (_, errors) = parseConfig(
            """
            [exec]
                inherit-env-vars = true
            """,
        )
        assertEquals(
            errors.descriptions,
            ["exec: Unknown top-level key"],
        )
    }

    func testConfigVersionIsUnknownTopLevelKeyParseError() {
        let (_, errors) = parseConfig(
            """
            config-version = 2
            """,
        )
        assertEquals(
            errors.descriptions,
            ["config-version: Unknown top-level key"],
        )
    }

    func testUnknownKeyParseError() {
        let (_, errors) = parseConfig(
            """
            [gaps]
                unknownKey = true
            """,
        )
        assertEquals(
            errors.descriptions,
            ["gaps.unknownKey: Unknown key"],
        )
    }

    func testTypeMismatch() {
        let (_, errors) = parseConfig(
            """
            start-at-login = 'true'
            """,
        )
        assertEquals(
            errors.descriptions,
            ["start-at-login: Expected type is \'bool\'. But actual type is \'string\'"],
        )
    }

    func testTomlParseError() {
        let (_, errors) = parseConfig("true")
        assertEquals(
            errors.descriptions,
            ["Error while parsing key-value pair: encountered end-of-file (at line 1, column 5)"],
        )
    }

    func testParseLayout() {
        let command = parseCommand("layout tiling floating").cmdOrNil
        XCTAssertTrue(command is LayoutCommand)
        assertEquals((command as! LayoutCommand).args.toggleBetween.val, [.tiling, .floating])

        guard case .help = parseCommand("layout -h") else {
            XCTFail()
            return
        }
    }

    func testParseWorkspaceToMonitorAssignment() {
        let (parsed, errors) = parseConfig(
            """
            [workspace-to-monitor-force-assignment]
                workspace_name_1 = 1                            # Sequence number of the monitor (from left to right, 1-based indexing)
                workspace_name_2 = 'main'                       # main monitor
                workspace_name_3 = 'secondary'                  # non-main monitor (in case when there are only two monitors)
                workspace_name_4 = 'built-in'                   # case insensitive regex substring
                workspace_name_5 = '^built-in retina display$'  # case insensitive regex match
                workspace_name_6 = ['secondary', 1]             # you can specify multiple patterns. The first matching pattern will be used
                7 = "foo"
                w7 = ['', 'main']
                w8 = 0
                workspace_name_x = '2'                          # Sequence number of the monitor (from left to right, 1-based indexing)
            """,
        )
        assertEquals(
            parsed.workspaceToMonitorForceAssignment,
            [
                "workspace_name_1": [.sequenceNumber(1)],
                "workspace_name_2": [.main],
                "workspace_name_3": [.secondary],
                "workspace_name_4": [.caseSensitivePattern("built-in")!],
                "workspace_name_5": [.caseSensitivePattern("^built-in retina display$")!],
                "workspace_name_6": [.secondary, .sequenceNumber(1)],
                "workspace_name_x": [.sequenceNumber(2)],
                "7": [.caseSensitivePattern("foo")!],
                "w7": [.main],
                "w8": [],
            ],
        )
        assertEquals([
            "workspace-to-monitor-force-assignment.w7[0]: Empty string is an illegal monitor description",
            "workspace-to-monitor-force-assignment.w8: Monitor sequence numbers uses 1-based indexing. Values less than 1 are illegal",
        ], errors.descriptions)
        assertEquals([:], defaultConfig.workspaceToMonitorForceAssignment)
    }

    func testRegex() {
        var devNull: [String] = []
        XCTAssertTrue("System Settings".contains(parseCaseInsensitiveRegex("settings").getOrNil(appendErrorTo: &devNull)!))
        XCTAssertTrue(!"System Settings".contains(parseCaseInsensitiveRegex("^settings^").getOrNil(appendErrorTo: &devNull)!))
    }

    func testParseGaps() {
        let (config, errors1) = parseConfig(
            """
            [gaps]
                inner.horizontal = 10
                inner.vertical = [{ monitor."main" = 1 }, { monitor."secondary" = 2 }, 5]
                outer.left = 12
                outer.bottom = 13
                outer.top = [{ monitor."built-in" = 3 }, { monitor."secondary" = 4 }, 6]
                outer.right = [{ monitor.2 = 7 }, 8]
            """,
        )
        assertEquals(errors1, [])
        assertEquals(
            config.gaps,
            Gaps(
                inner: .init(
                    vertical: .perMonitor(
                        [PerMonitorValue(description: .main, value: 1), PerMonitorValue(description: .secondary, value: 2)],
                        default: 5,
                    ),
                    horizontal: .constant(10),
                ),
                outer: .init(
                    left: .constant(12),
                    bottom: .constant(13),
                    top: .perMonitor(
                        [
                            PerMonitorValue(description: .caseSensitivePattern("built-in")!, value: 3),
                            PerMonitorValue(description: .secondary, value: 4),
                        ],
                        default: 6,
                    ),
                    right: .perMonitor([PerMonitorValue(description: .sequenceNumber(2), value: 7)], default: 8),
                ),
            ),
        )

        let (_, errors2) = parseConfig(
            """
            [gaps]
                inner.horizontal = [true]
                inner.vertical = [{ foo.main = 1 }, { monitor = { foo = 2, bar = 3 } }, 1]
            """,
        )
        assertEquals(errors2.descriptions, [
            "gaps.inner.horizontal: The last item in the array must be of type Int",
            "gaps.inner.vertical[0]: The table is expected to have a single key \'monitor\'",
            "gaps.inner.vertical[1].monitor: The table is expected to have a single key",
        ])
    }

    func testParseKeyMapping() {
        let (config, errors) = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
                q = 'q'
                unicorn = 'u'

            [binding]
                alt-unicorn = 'workspace wonderland'
            """,
        )
        assertEquals(errors.descriptions, [])
        assertEquals(config.keyMapping, KeyMapping(preset: .qwerty, rawKeyNotationToKeyCode: [
            "q": .q,
            "unicorn": .u,
        ]))
        let binding = HotkeyBinding(.option, .u, [WorkspaceCommand(args: WorkspaceCmdArgs(target: .direct(.parse("unicorn").getOrDie())))])
        assertEquals(config.bindings, [binding.descriptionWithKeyCode: binding])

        let (_, errors1) = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
                q = 'qw'
                ' f' = 'f'
            """,
        )
        assertEquals(errors1.descriptions, [
            "key-mapping.key-notation-to-key-code: ' f' is invalid key notation",
            "key-mapping.key-notation-to-key-code.q: 'qw' is invalid key code",
        ])

        let (dvorakConfig, dvorakErrors) = parseConfig(
            """
            key-mapping.preset = 'dvorak'
            """,
        )
        assertEquals(dvorakErrors, [])
        assertEquals(dvorakConfig.keyMapping, KeyMapping(preset: .dvorak, rawKeyNotationToKeyCode: [:]))
        assertEquals(dvorakConfig.keyMapping.resolve()["quote"], .q)
        let (colemakConfig, colemakErrors) = parseConfig(
            """
            key-mapping.preset = 'colemak'
            """,
        )
        assertEquals(colemakErrors, [])
        assertEquals(colemakConfig.keyMapping, KeyMapping(preset: .colemak, rawKeyNotationToKeyCode: [:]))
        assertEquals(colemakConfig.keyMapping.resolve()["f"], .e)
    }
}
