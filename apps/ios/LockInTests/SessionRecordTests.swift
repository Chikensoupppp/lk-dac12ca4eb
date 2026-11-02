import XCTest
@testable import LockIn

final class SessionRecordTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: UserDefaultsSessionStore!
    private let start = Date(timeIntervalSince1970: 10_000)

    override func setUp() {
        defaults = UserDefaults(suiteName: "LockInTests.\(UUID().uuidString)")
        store = UserDefaultsSessionStore(defaults: defaults)
    }

    private func record(duration: TimeInterval = 600) -> SessionRecord {
        SessionRecord(timing: SessionTiming(startedAt: start, duration: duration))
    }

    func testRoundTripPreservesTiming() {
        let saved = record()
        store.save(saved)
        let loaded = store.load()
        XCTAssertEqual(loaded, saved)
        XCTAssertEqual(loaded?.timing.endsAt, start.addingTimeInterval(600))
    }

    func testNoRecordIsIdle() {
        XCTAssertEqual(SessionRecovery.resolve(store.load(), now: start), .idle)
    }

    func testActiveSessionIsRestored() {
        let saved = record()
        store.save(saved)
        let now = start.addingTimeInterval(120)
        XCTAssertEqual(SessionRecovery.resolve(store.load(), now: now), .active(saved))
        XCTAssertEqual(saved.timing.remaining(at: now), 480)
    }

    func testRelaunchAfterExpiryAndExactBoundary() {
        let saved = record()
        XCTAssertEqual(SessionRecovery.resolve(saved, now: start.addingTimeInterval(599.9)), .active(saved))
        XCTAssertEqual(SessionRecovery.resolve(saved, now: start.addingTimeInterval(600)), .expired(saved))
        XCTAssertEqual(SessionRecovery.resolve(saved, now: start.addingTimeInterval(86_400)), .expired(saved))
    }

    func testCompletionIsOneShotOnceCleared() {
        store.save(record())
        let now = start.addingTimeInterval(700)
        guard case .expired = SessionRecovery.resolve(store.load(), now: now) else {
            return XCTFail("expected expired")
        }
        store.clear()
        // A second launch finds nothing, so completion cannot repeat.
        XCTAssertEqual(SessionRecovery.resolve(store.load(), now: now), .idle)
    }

    func testEarlyCancellationClearsAndIsIdempotent() {
        store.save(record())
        store.clear()
        store.clear()
        XCTAssertNil(store.load())
    }

    func testClockMovedBackwardsDiscardsRecord() {
        let saved = record()
        // Device clock is now an hour before the session start: the end is far beyond duration.
        XCTAssertEqual(SessionRecovery.resolve(saved, now: start.addingTimeInterval(-3600)), .idle)
        // Small skew is tolerated.
        XCTAssertEqual(SessionRecovery.resolve(saved, now: start.addingTimeInterval(-30)), .active(saved))
    }

    func testInvalidDurationAndCorruptDataAreIdle() {
        XCTAssertEqual(SessionRecovery.resolve(record(duration: 0), now: start), .idle)
        XCTAssertEqual(SessionRecovery.resolve(record(duration: -5), now: start), .idle)
        defaults.set(Data("not json".utf8), forKey: UserDefaultsSessionStore.key)
        XCTAssertNil(store.load())
        XCTAssertEqual(SessionRecovery.resolve(store.load(), now: start), .idle)
    }
}
