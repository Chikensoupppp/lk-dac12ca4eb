import XCTest
@testable import LockIn

final class SessionTimingTests: XCTestCase {
    func testBoundariesAndFraction() {
        let start = Date(timeIntervalSince1970: 1000)
        let session = SessionTiming(startedAt: start, duration: 60)
        XCTAssertEqual(session.endsAt, start.addingTimeInterval(60))
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(-1)), 60)
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(30)), 30)
        XCTAssertEqual(session.fractionRemaining(at: start.addingTimeInterval(30)), 0.5)
        XCTAssertFalse(session.isFinished(at: start.addingTimeInterval(59)))
        XCTAssertTrue(session.isFinished(at: session.endsAt))
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(61)), 0)
    }

    func testFormattingAndZeroDuration() {
        XCTAssertEqual(SessionTiming.display(seconds: 5400), "90:00")
        XCTAssertEqual(SessionTiming.display(seconds: -1), "00:00")
        let session = SessionTiming(startedAt: Date(), duration: 0)
        XCTAssertEqual(session.fractionRemaining(at: session.startedAt), 0)
        let invalid = SessionTiming(startedAt: Date(), duration: -5)
        XCTAssertEqual(invalid.remaining(at: invalid.startedAt), 0)
        XCTAssertEqual(invalid.fractionRemaining(at: invalid.startedAt), 0)
    }
}
