import XCTest
@testable import LockIn

final class StreakTests: XCTestCase {
    private var defaults: UserDefaults!
    private var calendar: Calendar!
    private let noon = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 11, day: 5, hour: 12)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "StreakTests")!
        defaults.removePersistentDomain(forName: "StreakTests")
        calendar = Calendar(identifier: .gregorian)
    }

    private func day(_ offset: Int) -> Date {
        let base = calendar.date(from: noon)!
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    func testFirstSessionOfTheDayReturnsTrueOnce() {
        XCTAssertTrue(StreakStore.record(day(0), calendar: calendar, defaults: defaults))
        XCTAssertFalse(StreakStore.record(day(0), calendar: calendar, defaults: defaults))
    }

    func testStreakCountsDaysInARow() {
        for offset in [-2, -1, 0] { StreakStore.record(day(offset), calendar: calendar, defaults: defaults) }
        XCTAssertEqual(StreakStore.current(now: day(0), calendar: calendar, defaults: defaults), 3)
    }

    func testOneMissedDayDoesNotBreakTheStreak() {
        for offset in [-3, -2, 0] { StreakStore.record(day(offset), calendar: calendar, defaults: defaults) }
        // day -1 was missed; the rest day keeps the run alive: 3 finished days.
        XCTAssertEqual(StreakStore.current(now: day(0), calendar: calendar, defaults: defaults), 3)
        XCTAssertTrue(StreakStore.usedRestDayRecently(now: day(0), calendar: calendar, defaults: defaults))
    }

    func testTwoMissedDaysInARowBreakTheStreak() {
        StreakStore.record(day(0), calendar: calendar, defaults: defaults)
        XCTAssertEqual(StreakStore.current(now: day(1), calendar: calendar, defaults: defaults), 1)
        // Day 2 is a rest day (still alive, one finished day). Day 3 would be a second miss in a row.
        XCTAssertEqual(StreakStore.current(now: day(2), calendar: calendar, defaults: defaults), 1)
        XCTAssertEqual(StreakStore.current(now: day(3), calendar: calendar, defaults: defaults), 0)
    }

    func testRestDayCanBeUsedOnlyOnceInSevenDays() {
        // Finished days 0, 2, 4: misses on 1 and 3 are only 2 days apart, so the second one breaks.
        for offset in [0, 2, 4] { StreakStore.record(day(offset), calendar: calendar, defaults: defaults) }
        XCTAssertEqual(StreakStore.current(now: day(4), calendar: calendar, defaults: defaults), 2)
    }

    func testRestDayAgainAfterAWeek() {
        // Misses on days 1 and 9 are 8 days apart, so both are forgiven.
        for offset in [0, 2, 3, 4, 5, 6, 7, 8, 10] { StreakStore.record(day(offset), calendar: calendar, defaults: defaults) }
        XCTAssertEqual(StreakStore.current(now: day(10), calendar: calendar, defaults: defaults), 9)
    }

    func testNoSessionsMeansNoStreak() {
        XCTAssertEqual(StreakStore.current(now: day(0), calendar: calendar, defaults: defaults), 0)
    }

    func testWeekRowMarksFinishedDaysFirst() {
        StreakStore.record(day(0), calendar: calendar, defaults: defaults)
        let week = StreakStore.week(now: day(0), calendar: calendar, defaults: defaults)
        XCTAssertEqual(week.count, 5)
        XCTAssertTrue(week[0].done)
        XCTAssertFalse(week[1].done)
    }
}
