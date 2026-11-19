import XCTest
@testable import LockIn

final class PlanTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "PlanTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    /// A fixed Wednesday afternoon in a normal week.
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        FocusLog.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testMorePhoneTimeGetsABiggerPlan() {
        let small = PlanRules.make(hoursIndex: 0, pulls: [], goals: [])
        let big = PlanRules.make(hoursIndex: 3, pulls: ["Video"], goals: ["Study"])
        XCTAssertEqual(small.minutesPerDay, 25)
        XCTAssertEqual(big.sessionsPerDay, 3)
        XCTAssertEqual(big.minutes, 45)
        XCTAssertEqual(big.startMinute, 16 * 60)
        XCTAssertEqual(big.task, "Studying")
        XCTAssertEqual(big.weekdays, [2, 3, 4, 5, 6])
        XCTAssertEqual(PlanRules.make(hoursIndex: nil, pulls: [], goals: []).minutesPerDay, 25)
    }

    func testSlotsRunBackToBack() {
        let plan = PlanRules.make(hoursIndex: 2, pulls: [], goals: ["Study"])
        let slots = plan.slots(on: date(2026, 11, 18))
        let cal = FocusLog.calendar
        XCTAssertEqual(slots.map { cal.component(.hour, from: $0) * 60 + cal.component(.minute, from: $0) }, [960, 1005])
    }

    func testStepUpKeepAndEasierStayOnTheLadder() {
        let mid = PlanRules.make(hoursIndex: 1, pulls: [], goals: [])
        XCTAssertEqual(PlanRules.apply(.stepUp, to: mid).minutesPerDay, 90)
        XCTAssertEqual(PlanRules.apply(.easier, to: mid).minutesPerDay, 25)
        XCTAssertEqual(PlanRules.apply(.keep, to: mid), mid)
        let top = PlanRules.make(hoursIndex: 3, pulls: [], goals: [])
        XCTAssertEqual(PlanRules.apply(.stepUp, to: top), top)
        let bottom = PlanRules.make(hoursIndex: 0, pulls: [], goals: [])
        XCTAssertEqual(PlanRules.apply(.easier, to: bottom), bottom)
    }

    func testSuggestionFollowsTheWeek() {
        let plan = PlanRules.make(hoursIndex: 1, pulls: [], goals: [])
        XCTAssertEqual(PlanRules.suggestion(done: 10, planned: 10, plan: plan), .stepUp)
        XCTAssertEqual(PlanRules.suggestion(done: 6, planned: 10, plan: plan), .keep)
        XCTAssertEqual(PlanRules.suggestion(done: 2, planned: 10, plan: plan), .easier)
        XCTAssertEqual(PlanRules.suggestion(done: 0, planned: 0, plan: plan), .keep)
    }

    func testProgressCountsTodaysFinishedLockIns() {
        let wed = date(2026, 11, 18, 17)
        let plan = PlanRules.make(hoursIndex: 1, pulls: [], goals: ["Study"], now: date(2026, 11, 16))
        FocusLog.recordFinished(minutes: 25, at: wed, defaults: defaults)
        FocusLog.recordQuit(minutes: 10, at: wed, defaults: defaults)
        let p = PlanProgress.make(plan: plan, now: wed, defaults: defaults)
        XCTAssertEqual(p.today?.done, 1)
        XCTAssertEqual(p.today?.planned, 2)
        XCTAssertEqual(p.minutesToday, 35)
        XCTAssertEqual(p.week.count, 5)
        XCTAssertNotNil(p.nextSlot(plan: plan, now: wed))
        // A Saturday is not a plan day.
        XCTAssertNil(PlanProgress.make(plan: plan, now: date(2026, 11, 21), defaults: defaults).today)
    }

    func testCheckInWaitsForAFullWeekAndOnlyOnce() {
        let plan = PlanRules.make(hoursIndex: 1, pulls: [], goals: [], now: date(2026, 11, 17))
        PlanStore.save(plan, defaults)
        XCTAssertEqual(defaults.integer(forKey: "lockin.minutes.v1"), 25)
        // Same week the plan started: nothing to check in yet.
        XCTAssertNil(PlanStore.pendingCheckIn(now: date(2026, 11, 20), defaults))
        // The next Monday: last week is due.
        let due = PlanStore.pendingCheckIn(now: date(2026, 11, 23), defaults)
        XCTAssertNotNil(due)
        let result = PlanWeekResult.make(plan: plan, weekOf: due!, defaults: defaults)
        XCTAssertEqual(result.number, 1)
        XCTAssertEqual(result.planned, 8)   // Tue to Fri, 2 a day: the plan started on Tuesday
        PlanStore.markCheckedIn(week: due!, defaults)
        XCTAssertNil(PlanStore.pendingCheckIn(now: date(2026, 11, 23), defaults))
    }
}
