@testable import AppBundle
import Common
import XCTest

final class WorkspaceChangeHookTest: XCTestCase {
    func testWorkspaceChangeHookEnvironment() {
        let env = workspaceChangeHookEnvironment(
            newWorkspace: "7",
            baseEnv: [
                "PATH": "/usr/bin:/bin",
                "CUSTOM_VAR": "custom",
            ],
        )

        assertEquals(env[FRAME_FOCUSED_WORKSPACE], "7")
        assertEquals(env["PATH"], "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin")
        assertEquals(env["CUSTOM_VAR"], "custom")
    }
}
