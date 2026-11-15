import XCTest
@testable import LockIn

/// Ending a session early is neutral: the minutes already focused still count, the session is not
/// counted as finished (so the streak is untouched), and nothing is "scarred".
final class PartialCreditTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PartialCreditTests")!
        defaults.removePersistentDomain(forName: "PartialCreditTests")
    }

    func testEarlyEndKeepsFocusedMinutesButNotAFinishedSession() {
        let day = Date()
        FocusLog.recordQuit(minutes: 12, at: day, defaults: defaults)
        let week = FocusLog.week(of: day, defaults: defaults)
        XCTAssertEqual(week.minutes, 12)
        XCTAssertEqual(week.sessions, 0)
        XCTAssertEqual(week.quits, 1)
    }

    func testEarlyEndWithNoTimeAddsNothing() {
        let day = Date()
        FocusLog.recordQuit(minutes: 0, at: day, defaults: defaults)
        FocusLog.recordQuit(minutes: -5, at: day, defaults: defaults)
        let week = FocusLog.week(of: day, defaults: defaults)
        XCTAssertEqual(week.minutes, 0)
        XCTAssertEqual(week.sessions, 0)
    }

    func testFinishedAndPartialAddUp() {
        let day = Date()
        FocusLog.recordFinished(minutes: 25, at: day, defaults: defaults)
        FocusLog.recordQuit(minutes: 10, at: day, defaults: defaults)
        let week = FocusLog.week(of: day, defaults: defaults)
        XCTAssertEqual(week.minutes, 35)
        XCTAssertEqual(week.sessions, 1)
    }
}
