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

    func testStreakSurvivesUntilEndOfTomorrowButBreaksAfterAGap() {
        StreakStore.record(day(0), calendar: calendar, defaults: defaults)
        XCTAssertEqual(StreakStore.current(now: day(1), calendar: calendar, defaults: defaults), 1)
        XCTAssertEqual(StreakStore.current(now: day(2), calendar: calendar, defaults: defaults), 0)
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
