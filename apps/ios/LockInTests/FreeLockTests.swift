import XCTest
@testable import LockIn

/// Free users get one Locked session a week (QuitRules.freeLockAvailable / useFreeLock).
final class FreeLockTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "FreeLockTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testOneFreeLockedSessionAWeek() {
        XCTAssertTrue(QuitRules.freeLockAvailable(defaults), "a new user has this week's free one")
        QuitRules.useFreeLock(defaults)
        XCTAssertFalse(QuitRules.freeLockAvailable(defaults), "used up for the rest of the week")
    }

    func testANewWeekGivesItBack() {
        // Used in an earlier week: the key holds that week, not this one.
        defaults.set("2001-W1", forKey: "lockin.freeLock.week.v1")
        XCTAssertTrue(QuitRules.freeLockAvailable(defaults))
    }
}
