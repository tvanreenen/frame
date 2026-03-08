@testable import FrameEngine
@testable import FrameMacOS
@testable import FrameUI
import Common
import XCTest
import FrameTestSupport

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
