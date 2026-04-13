import Common
import XCTest
import FrameTestSupport

final class VersionPresentationTest: XCTestCase {
    func testDoctorOutputWhenDaemonIsNotRunning() {
        let result = VersionPresentation.doctorOutput(
            cliVersion: "0.12.3+abc1234",
            daemonVersion: nil,
            configHealthy: nil,
            configDetails: nil,
        )
        XCTAssertEqual(
            result,
            """
            CLI Version: 0.12.3+abc1234
            Daemon Version: Not Running
            Versions Match: Unknown (daemon not running)
            Config Location: Unknown
            Config Status: Unknown (daemon not running)
            """,
        )
    }

    func testDoctorOutputWhenDaemonIsRunningAndHealthy() {
        let result = VersionPresentation.doctorOutput(
            cliVersion: "0.12.3+abc1234",
            daemonVersion: "0.12.3+abc1234",
            configHealthy: true,
            configDetails: "Config is valid: /tmp/frame.toml",
        )
        XCTAssertEqual(
            result,
            """
            CLI Version: 0.12.3+abc1234
            Daemon Version: 0.12.3+abc1234
            Versions Match: Yes
            Config Location: /tmp/frame.toml
            Config Status: Valid
            """,
        )
    }

    func testDoctorOutputWhenDaemonVersionMismatch() {
        let result = VersionPresentation.doctorOutput(
            cliVersion: "0.12.3+abc1234",
            daemonVersion: "0.12.3+def5678",
            configHealthy: true,
            configDetails: "Config is valid: /tmp/frame.toml",
        )
        XCTAssertEqual(
            result,
            """
            CLI Version: 0.12.3+abc1234
            Daemon Version: 0.12.3+def5678
            Versions Match: No
            Config Location: /tmp/frame.toml
            Config Status: Valid
            """,
        )
    }

    func testDoctorOutputWhenConfigIsUnhealthy() {
        let result = VersionPresentation.doctorOutput(
            cliVersion: "0.12.3+abc1234",
            daemonVersion: "0.12.3+abc1234",
            configHealthy: false,
            configDetails: "Failed to parse /tmp/frame.toml",
        )
        XCTAssertEqual(
            result,
            """
            CLI Version: 0.12.3+abc1234
            Daemon Version: 0.12.3+abc1234
            Versions Match: Yes
            Config Location: /tmp/frame.toml
            Config Status: Invalid
            Config Issues:
            Unknown configuration error
            """,
        )
    }

    func testDoctorOutputWhenConfigIsUnhealthyWithDetailedErrors() {
        let result = VersionPresentation.doctorOutput(
            cliVersion: "0.12.3+abc1234",
            daemonVersion: "0.12.3+abc1234",
            configHealthy: false,
            configDetails: """
                Failed to parse /tmp/frame.toml

                [binding.alt-h]
                  - [CFG001] Unknown key

                Recovery:
                1. Fix and retry
                """,
        )
        XCTAssertEqual(
            result,
            """
            CLI Version: 0.12.3+abc1234
            Daemon Version: 0.12.3+abc1234
            Versions Match: Yes
            Config Location: /tmp/frame.toml
            Config Status: Invalid
            Config Issues:
            [binding.alt-h]
              - [CFG001] Unknown key
            """,
        )
    }

    func testDoctorExitCode() {
        XCTAssertEqual(VersionPresentation.doctorExitCode(cliVersion: "a", daemonVersion: nil, configHealthy: nil), 1)
        XCTAssertEqual(VersionPresentation.doctorExitCode(cliVersion: "a", daemonVersion: "b", configHealthy: true), 1)
        XCTAssertEqual(VersionPresentation.doctorExitCode(cliVersion: "a", daemonVersion: "a", configHealthy: false), 1)
        XCTAssertEqual(VersionPresentation.doctorExitCode(cliVersion: "a", daemonVersion: "a", configHealthy: true), 0)
    }
}
