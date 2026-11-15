import XCTest
@testable import LockIn

/// The daily reminder time, the optional if-then line, and the per-task allowed apps list.
final class HabitFeaturesTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "HabitFeaturesTests")!
        defaults.removePersistentDomain(forName: "HabitFeaturesTests")
    }

    func testSuggestedReminderIsTheSessionStartRoundedToFiveMinutes() {
        let calendar = Calendar(identifier: .gregorian)
        let finished = calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 15, minute: 47))!
        // 25 minutes focused, so it began at 15:22 and rounds to 15:20.
        XCTAssertEqual(DailyNudge.suggestedMinute(finishedAt: finished, focusedMinutes: 25, calendar: calendar), 15 * 60 + 20)
    }

    func testSuggestedReminderWrapsPastMidnight() {
        let calendar = Calendar(identifier: .gregorian)
        let finished = calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 0, minute: 10))!
        let minute = DailyNudge.suggestedMinute(finishedAt: finished, focusedMinutes: 25, calendar: calendar)
        XCTAssertTrue((0..<24 * 60).contains(minute))
    }

    func testIfThenLineIsOffByDefaultAndNeedsAText() {
        XCTAssertNil(IfThenPlan.line(on: false, cue: "I sit at my desk"))
        XCTAssertNil(IfThenPlan.line(on: true, cue: "   "))
        XCTAssertEqual(IfThenPlan.line(on: true, cue: " I sit at my desk "), "When I sit at my desk, I lock in.")
    }

    func testAllowedAppsAreKeptPerTaskWithoutDuplicates() {
        AllowedApps.add("Spotify", for: "Studying", defaults: defaults)
        AllowedApps.add("spotify", for: "Studying", defaults: defaults)
        AllowedApps.add("  ", for: "Studying", defaults: defaults)
        AllowedApps.add("notion.so", for: "Writing", defaults: defaults)
        XCTAssertEqual(AllowedApps.list(for: "Studying", defaults: defaults), ["Spotify"])
        XCTAssertEqual(AllowedApps.list(for: "Writing", defaults: defaults), ["notion.so"])
        XCTAssertEqual(AllowedApps.list(for: nil, defaults: defaults), [])
    }

    func testAllowedAppsCanBeRemovedAndAreCapped() {
        AllowedApps.add("Spotify", for: nil, defaults: defaults)
        AllowedApps.remove("Spotify", for: nil, defaults: defaults)
        XCTAssertEqual(AllowedApps.list(for: nil, defaults: defaults), [])
        for n in 0..<(AllowedApps.maxEntries + 5) { AllowedApps.add("App \(n)", for: nil, defaults: defaults) }
        XCTAssertEqual(AllowedApps.list(for: nil, defaults: defaults).count, AllowedApps.maxEntries)
    }
}
