import AppKit
@testable import FrameEngine
@testable import FrameMacOS
import FrameTestSupport
import XCTest

@MainActor
final class MacAppRegistrationTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testAppsWithoutProcessIdsAreSkipped() async throws {
        for pid: pid_t in [-1, 0] {
            let app = RegistrationTestApplication(pid: pid)

            let result = try await currentSession.getOrRegisterMacApp(app)

            XCTAssertNil(result)
            XCTAssertTrue(currentSession.appsByPid.isEmpty)
            XCTAssertTrue(currentSession.appsWipByPid.isEmpty)
        }
    }

    func testTerminatedAppsAreSkipped() async throws {
        let app = RegistrationTestApplication(pid: Int32.max, terminated: true)

        let result = try await currentSession.getOrRegisterMacApp(app)

        XCTAssertNil(result)
        XCTAssertTrue(currentSession.appsWipByPid.isEmpty)
    }

    func testNativeProcessIdDoesNotInspectWindowOwners() {
        let app = RegistrationTestApplication(pid: 123)
        func unexpectedLookup() -> [pid_t] {
            XCTFail("A valid AppKit PID should not require a WindowServer lookup")
            return []
        }

        XCTAssertEqual(app.resolveAccessibilityProcessIdentifier(windowOwnerPids: unexpectedLookup()), 123)
    }

    func testMissingProcessIdResolvesOneMatchingWindowOwner() throws {
        let owners = try liveApplications(count: 2)
        let app = RegistrationTestApplication(pid: -1, matchingApps: [owners[0]])
        let matchingPid = owners[0].processIdentifier

        let result = app.resolveAccessibilityProcessIdentifier(
            windowOwnerPids: [-1, 0, Int32.max, matchingPid, matchingPid, owners[1].processIdentifier],
        )

        XCTAssertEqual(result, matchingPid)
    }

    func testMissingProcessIdRejectsUnrelatedWindowOwners() throws {
        let owners = try liveApplications(count: 2)
        let app = RegistrationTestApplication(pid: -1, matchingApps: [owners[0]])

        XCTAssertNil(app.resolveAccessibilityProcessIdentifier(windowOwnerPids: [owners[1].processIdentifier]))
        XCTAssertNil(app.resolveAccessibilityProcessIdentifier(windowOwnerPids: []))
    }

    func testMissingProcessIdRejectsAmbiguousWindowOwners() throws {
        let owners = try liveApplications(count: 2)
        let app = RegistrationTestApplication(pid: -1, matchingApps: owners)

        XCTAssertNil(app.resolveAccessibilityProcessIdentifier(windowOwnerPids: owners.map(\.processIdentifier)))
    }

    private func liveApplications(count: Int) throws -> [NSRunningApplication] {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.processIdentifier > 0 && !$0.isTerminated }
        guard apps.count >= count else { throw XCTSkip("Requires live AppKit application identities") }
        return Array(apps.prefix(count))
    }

    func testFailedRegistrationReturnsAndCanBeRetriedByAnotherRefresh() async {
        // Keep the real AX calls: this positive PID has no target process, so
        // observer subscription fails even though AppKit metadata looks valid.
        let app = RegistrationTestApplication(pid: Int32.max)
        let session = currentSession
        let completed = expectation(description: "Failed AX registrations return")
        let task = Task { @MainActor in
            defer { completed.fulfill() }
            do {
                for _ in 0 ..< 2 {
                    let result = try await session.getOrRegisterMacApp(app)
                    XCTAssertNil(result)
                    XCTAssertTrue(session.appsByPid.isEmpty)
                    XCTAssertTrue(session.appsWipByPid.isEmpty)
                }
            } catch {
                XCTFail("Unexpected registration error: \(error)")
            }
        }
        defer { task.cancel() }

        await fulfillment(of: [completed], timeout: 2)
    }
}

private final class RegistrationTestApplication: NSRunningApplication, @unchecked Sendable {
    private let pid: pid_t
    private let hasExited: Bool
    private let matchingApps: [NSRunningApplication]

    init(pid: pid_t, terminated: Bool = false, matchingApps: [NSRunningApplication] = []) {
        self.pid = pid
        self.hasExited = terminated
        self.matchingApps = matchingApps
        super.init()
    }

    override var processIdentifier: pid_t { pid }
    override var isTerminated: Bool { hasExited }
    override var bundleIdentifier: String? { "test.frame.unobservable" }
    override func isEqual(_ object: Any?) -> Bool { matchingApps.contains { $0.isEqual(object) } }
}
