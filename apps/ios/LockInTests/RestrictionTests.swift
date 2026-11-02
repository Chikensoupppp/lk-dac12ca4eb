import FamilyControls
import XCTest
@testable import LockIn

@MainActor
private final class FakeClient: ScreenTimeClient {
    var authorization: ScreenTimeAuthorization = .approved
    var authorizationError: Error?
    var monitoringError: Error?
    private(set) var monitored: [String] = []
    private(set) var shieldApplied = false
    private(set) var clearCount = 0

    func requestAuthorization() async throws {
        if let authorizationError { throw authorizationError }
        authorization = .approved
    }

    func startMonitoring(activity: String, from: Date, to: Date) throws {
        if let monitoringError { throw monitoringError }
        monitored.append(activity)
    }

    func stopMonitoring() { monitored.removeAll() }
    func applyShield(_ selection: FamilyActivitySelection) { shieldApplied = true }
    func clearShield() { shieldApplied = false; clearCount += 1 }
}

private struct Boom: Error, LocalizedError { var errorDescription: String? { "boom" } }

final class RestrictionNamingTests: XCTestCase {
    private let id = UUID()
    private let end = Date(timeIntervalSince1970: 50_000)

    func testNameRoundTrip() {
        let name = RestrictionNaming.activityName(sessionID: id, endsAt: end)
        let parsed = RestrictionNaming.parse(name)
        XCTAssertEqual(parsed?.id, id)
        XCTAssertEqual(parsed?.endsAt, end)
        XCTAssertNil(RestrictionNaming.parse("other.activity"))
        XCTAssertNil(RestrictionNaming.parse(RestrictionNaming.activityPrefix + "garbage"))
    }

    func testCleanupIgnoresEarlyForeignAndSupersededCallbacks() {
        let name = RestrictionNaming.activityName(sessionID: id, endsAt: end)
        XCTAssertFalse(RestrictionNaming.shouldClearShield(endedActivity: name, monitored: [], now: end.addingTimeInterval(-10)))
        XCTAssertTrue(RestrictionNaming.shouldClearShield(endedActivity: name, monitored: [name], now: end))
        XCTAssertFalse(RestrictionNaming.shouldClearShield(endedActivity: "foreign", monitored: [], now: end.addingTimeInterval(10)))
        let newer = RestrictionNaming.activityName(sessionID: UUID(), endsAt: end.addingTimeInterval(3600))
        XCTAssertFalse(RestrictionNaming.shouldClearShield(endedActivity: name, monitored: [name, newer], now: end.addingTimeInterval(10)))
        let older = RestrictionNaming.activityName(sessionID: UUID(), endsAt: end.addingTimeInterval(-3600))
        XCTAssertTrue(RestrictionNaming.shouldClearShield(endedActivity: name, monitored: [name, older], now: end.addingTimeInterval(10)))
    }
}

final class RestrictionPlannerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000.4)

    private func record(minutes: Double) -> SessionRecord {
        SessionRecord(timing: SessionTiming(startedAt: start, duration: minutes * 60))
    }

    func testSkipReasons() {
        let r = record(minutes: 25)
        XCTAssertEqual(RestrictionPlanner.plan(for: r, now: start, isAuthorized: false, hasSelection: true), .skip(.notAuthorized))
        XCTAssertEqual(RestrictionPlanner.plan(for: r, now: start, isAuthorized: true, hasSelection: false), .skip(.noSelection))
        XCTAssertEqual(RestrictionPlanner.plan(for: record(minutes: 14), now: start, isAuthorized: true, hasSelection: true), .skip(.tooShort))
        XCTAssertEqual(RestrictionPlanner.plan(for: r, now: r.timing.endsAt, isAuthorized: true, hasSelection: true), .skip(.alreadyExpired))
    }

    func testFifteenMinuteSessionGetsIntervalAboveApplesMinimum() {
        let r = record(minutes: 15)
        guard case .apply(_, let s, let e) = RestrictionPlanner.plan(for: r, now: start, isAuthorized: true, hasSelection: true) else {
            return XCTFail("expected apply")
        }
        XCTAssertGreaterThanOrEqual(e.timeIntervalSince(s), RestrictionNaming.minimumMonitoringInterval)
        XCTAssertGreaterThanOrEqual(e, r.timing.endsAt)
    }
}

@MainActor
final class RestrictionControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var client: FakeClient!

    override func setUp() {
        defaults = UserDefaults(suiteName: "LockInRestrictionTests.\(UUID().uuidString)")
        client = FakeClient()
    }

    private func controller() -> RestrictionController {
        RestrictionController(client: client, defaults: defaults, selectionIsEmpty: { _ in false })
    }

    private func record(minutes: Double = 25) -> SessionRecord {
        SessionRecord(timing: SessionTiming(startedAt: .now, duration: minutes * 60))
    }

    func testBeginSchedulesBackupThenShieldsAndEndRemovesBoth() {
        let c = controller()
        c.begin(record())
        XCTAssertEqual(c.status, .active)
        XCTAssertTrue(client.shieldApplied)
        XCTAssertEqual(client.monitored.count, 1)
        XCTAssertNotNil(c.appliedMarker)
        c.end()
        c.end()
        XCTAssertFalse(client.shieldApplied)
        XCTAssertTrue(client.monitored.isEmpty)
        XCTAssertNil(c.appliedMarker)
    }

    func testDeniedAuthorizationNeverShields() {
        client.authorization = .denied
        let c = controller()
        XCTAssertEqual(c.status, .denied)
        c.begin(record())
        XCTAssertEqual(c.status, .skipped(.notAuthorized))
        XCTAssertFalse(client.shieldApplied)
    }

    func testFailedSchedulingAppliesNoShield() {
        client.monitoringError = Boom()
        let c = controller()
        c.begin(record())
        XCTAssertEqual(c.status, .failed("boom"))
        XCTAssertFalse(client.shieldApplied)
        XCTAssertNil(c.appliedMarker)
    }

    func testShortSessionGetsNoShield() {
        let c = controller()
        c.begin(record(minutes: 5))
        XCTAssertEqual(c.status, .skipped(.tooShort))
        XCTAssertFalse(client.shieldApplied)
    }

    func testAuthorizationFailureIsReported() async {
        client.authorization = .notDetermined
        client.authorizationError = Boom()
        let c = controller()
        await c.requestAuthorization()
        XCTAssertEqual(c.status, .failed("boom"))
    }

    func testReconcileClearsStaleAndRevokedState() {
        let r = record()
        let c = controller()
        c.begin(r)
        // Same session still running: keep.
        c.reconcile(activeSessionID: r.id)
        XCTAssertTrue(client.shieldApplied)
        // Relaunch with no active session (cancelled or expired while closed): clear.
        c.reconcile(activeSessionID: nil)
        XCTAssertFalse(client.shieldApplied)

        c.begin(r)
        // A different session is active: the old marker is stale.
        c.reconcile(activeSessionID: UUID())
        XCTAssertFalse(client.shieldApplied)

        c.begin(r)
        // Authorization revoked mid-session.
        client.authorization = .denied
        c.reconcile(activeSessionID: r.id)
        XCTAssertFalse(client.shieldApplied)
        XCTAssertEqual(c.status, .denied)
    }

    func testReconcileAfterExpiryClears() {
        let r = record()
        let c = controller()
        c.begin(r)
        c.reconcile(activeSessionID: r.id, now: r.timing.endsAt)
        XCTAssertFalse(client.shieldApplied)
    }
}
