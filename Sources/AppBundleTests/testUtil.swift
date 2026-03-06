@testable import AppBundle
import Common
import Foundation
import HotKey
import XCTest

let projectRoot: URL = {
    var url = URL(filePath: #filePath).absoluteURL
    check(FileManager.default.fileExists(atPath: url.path))
    while !FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
        url.deleteLastPathComponent()
    }
    return url
}()

@MainActor
func setUpWorkspacesForTests() {
    runtimeContext.config = defaultConfig
    runtimeContext.configUrl = defaultConfigUrl
    runtimeContext.windowsById = [:]
    runtimeContext.appsByPid = [:]
    runtimeContext.appsWipByPid = [:]
    runtimeContext.appFocusJob = nil
    runtimeContext.closedWindowsCache = FrozenWorld(workspaces: [], monitors: [], windowIds: [])

    // Don't create any bindings and workspaces for tests
    runtimeContext.config.bindings = [:]
    runtimeContext.config.persistentWorkspaces = []

    for workspace in Workspace.all {
        clearWorkspaceChildrenForTests(workspace)
    }
    check(Workspace.get(byName: "setUpWorkspacesForTests").focusWorkspace())
    Workspace.garbageCollectUnusedWorkspaces()
    check(focus.workspace.isEffectivelyEmpty)
    check(focus.workspace === Workspace.all.singleOrNil(), Workspace.all.map(\.description).joined(separator: ", "))
    check(mainMonitor.setActiveWorkspace(focus.workspace))

    Window.resetForTests()
    TestApp.shared.resetState()
    appForTests = nil
}

@MainActor
func clearWorkspaceChildrenForTests(_ workspace: Workspace) {
    for child in Array(workspace.columnsRoot.children) {
        child.unbindFromParent()
    }
    for child in Array(workspace.children) where child !== workspace.columnsRoot {
        child.unbindFromParent()
    }
}

extension ParsedCmd {
    var errorOrNil: String? {
        if case .failure(let e) = self {
            return e
        } else {
            return nil
        }
    }

    var cmdOrDie: T { cmdOrNil ?? dieT() }

    var isHelp: Bool {
        if case .help = self {
            return true
        } else {
            return false
        }
    }
}

func testParseCommandFail(_ command: String, msg expected: String) {
    let parsed = parseCommand(command)
    switch parsed {
        case .cmd(let command): XCTFail("\(command) isn't supposed to be parcelable")
        case .failure(let msg): assertEquals(msg, expected)
        case .help: die() // todo test help
    }
}

extension WorkspaceCmdArgs {
    init(target: WorkspaceTarget, wrapAround: Bool? = nil) {
        self = WorkspaceCmdArgs(rawArgs: [])
        self.target = .initialized(target)
        self._wrapAround = wrapAround
    }
}

extension MoveNodeToWorkspaceCmdArgs {
    init(target: WorkspaceTarget, wrapAround: Bool? = nil) {
        self = MoveNodeToWorkspaceCmdArgs(rawArgs: [])
        self.target = .initialized(target)
        self._wrapAround = wrapAround
    }

    init(workspace: String) {
        self = MoveNodeToWorkspaceCmdArgs(rawArgs: [])
        self.target = .initialized(.direct(.parse(workspace).getOrDie()))
    }
}
