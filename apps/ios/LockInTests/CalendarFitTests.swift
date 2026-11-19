import XCTest
@testable import LockIn

/// Fitting the plan's time around the calendar ("Can't do 4:00?"), and the auto-lock names.
final class CalendarFitTests: XCTestCase {
    private var cal: Calendar!
    /// Monday 2026-11-16, 9:00.
    private var monday: Date!

    override func setUp() {
        super.setUp()
        cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        monday = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 9))!
    }

    private func at(_ dayOffset: Int, _ hour: Double) -> Date {
        let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: monday))!
        return day.addingTimeInterval(hour * 3600)
    }

    private func busy(_ day: Int, _ from: Double, _ to: Double, _ title: String) -> CalendarFit.Busy {
        CalendarFit.Busy(start: at(day, from), end: at(day, to), title: title, allDay: false)
    }

    func testKindsReadWhatTheEventIs() {
        XCTAssertEqual(CalendarFit.kind(of: "Knee surgery"), .dayOff)
        XCTAssertEqual(CalendarFit.kind(of: "Away game vs Lincoln"), .dayOff)
        XCTAssertEqual(CalendarFit.kind(of: "Chem exam"), .buffer)
        XCTAssertEqual(CalendarFit.kind(of: "Soccer practice"), .buffer)
        XCTAssertEqual(CalendarFit.kind(of: "Latest episode"), .normal, "whole words only")
        XCTAssertEqual(CalendarFit.kind(of: "Campus tour"), .normal, "camp is not campus")
        XCTAssertEqual(CalendarFit.kind(of: "Dinner with Sam"), .normal)
    }

    func testDaysAreMondayFirstAndMarkADayOff() {
        let events = [busy(2, 15, 23, "Away game")]
        let days = CalendarFit.days(weekdays: [2, 3, 4, 5, 6], events: events, from: monday, calendar: cal)
        XCTAssertEqual(days.map(\.weekday), [2, 3, 4, 5, 6])
        XCTAssertEqual(days[2].dayOff, "Away game")
        XCTAssertNil(days[0].dayOff)
    }

    func testBufferAddsTimeAroundAnExam() {
        let days = CalendarFit.days(weekdays: [2], events: [busy(0, 16, 17, "Math exam")], from: monday, calendar: cal)
        XCTAssertEqual(days[0].busy, [(15 * 60 + 30)...(17 * 60 + 30)])
        XCTAssertFalse(CalendarFit.isFree(days[0], start: 17 * 60 + 15, minutes: 30))
        XCTAssertTrue(CalendarFit.isFree(days[0], start: 17 * 60 + 30, minutes: 30))
    }

    func testBestFitIsTheTimeFreeOnTheMostDays() {
        let events = [busy(0, 16, 17, "Class"), busy(1, 16, 17.25, "Work"), busy(3, 16, 17, "Class")]
        let days = CalendarFit.days(weekdays: [2, 3, 4, 5, 6], events: events, from: monday, calendar: cal)
        let best = CalendarFit.suggestions(days: days, minutes: 50, near: 16 * 60)
        XCTAssertFalse(best.isEmpty)
        XCTAssertEqual(best[0].freeDays, 5)
        XCTAssertTrue(days.allSatisfy { CalendarFit.isFree($0, start: best[0].minute, minutes: 50) })
        XCTAssertTrue(zip(best, best.dropFirst()).allSatisfy { abs($0.minute - $1.minute) >= 45 })
    }

    func testEachDayMovesOnlyTheBusyDay() {
        let events = [busy(2, 17, 18.5, "Dentist")]
        let days = CalendarFit.days(weekdays: [2, 3, 4], events: events, from: monday, calendar: cal)
        let fit = CalendarFit.bestEachDay(days: days, minutes: 50, near: 17 * 60 + 30)
        XCTAssertEqual(fit[2], 17 * 60 + 30)
        XCTAssertEqual(fit[3], 17 * 60 + 30)
        XCTAssertNotEqual(fit[4], 17 * 60 + 30)
    }

    func testClashNamesTheEvent() {
        let days = CalendarFit.days(weekdays: [2], events: [busy(0, 19, 20, "Practice")], from: monday, calendar: cal)
        XCTAssertEqual(days[0].clash(start: 19 * 60, minutes: 50), "Practice")
        XCTAssertNil(days[0].clash(start: 17 * 60, minutes: 50))
    }

    func testPlanUsesItsPerDayStart() {
        var plan = PlanRules.make(hoursIndex: 1, pulls: [], goals: ["Study"], now: monday)
        plan.dayStarts = [4: 18 * 60 + 15]
        XCTAssertEqual(plan.startMinute(weekday: 4), 18 * 60 + 15)
        XCTAssertEqual(plan.startMinute(weekday: 2), plan.startMinute)
        let old = try! JSONEncoder().encode(PlanRules.make(hoursIndex: 1, pulls: [], goals: [], now: monday))
        XCTAssertNil(try JSONDecoder().decode(LockInPlan.self, from: old).dayStarts)
    }

    func testAutoLockNamesAndClearing() {
        let name = AutoLock.activityName(weekday: 3, startMinute: 1050, minutes: 50)
        XCTAssertEqual(AutoLock.parse(name)?.weekday, 3)
        XCTAssertFalse(AutoLock.isAuto("lockin.session.x"))
        let running = RestrictionNaming.activityName(sessionID: UUID(), endsAt: monday.addingTimeInterval(600))
        XCTAssertFalse(AutoLock.mayClear(monitored: [name, running], now: monday))
        XCTAssertTrue(AutoLock.mayClear(monitored: [name], now: monday))
    }
}
