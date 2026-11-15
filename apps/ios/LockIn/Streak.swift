import Foundation

/// Days with at least one finished focus session. Stored on the device only.
/// A day is its number inside the calendar era, so day math is safe across months and DST.
enum StreakStore {
    static let key = "lockin.finishedDays.v1"

    private static func dayNumber(_ date: Date, _ calendar: Calendar) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    static func finishedDays(_ defaults: UserDefaults = .standard) -> Set<Int> {
        Set(defaults.array(forKey: key) as? [Int] ?? [])
    }

    /// Saves a finished session. Returns true when it is the first one on that day.
    @discardableResult
    static func record(_ date: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Bool {
        var days = finishedDays(defaults)
        let inserted = days.insert(dayNumber(date, calendar)).inserted
        // Keep a year at most. The streak shows five days, so older days are not needed.
        let newest = days.max() ?? 0
        days = days.filter { $0 > newest - 366 }
        defaults.set(days.sorted(), forKey: key)
        return inserted
    }

    /// One walk back from today. A streak survives one missed day (a "rest day") as long as the
    /// days on both sides of it were finished, and a rest day can be used once in any 7 days.
    /// `count` is finished days only; `span` also counts the rest day, so the little row lines up.
    struct Run: Equatable {
        var count = 0
        var span = 0
        /// The rest day that was used most recently inside this streak (a day number), if any.
        var restDay: Int?
    }

    static func run(now: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Run {
        let days = finishedDays(defaults)
        let today = dayNumber(now, calendar)
        var day = today
        // Today with no session yet is not a miss; the streak is judged from yesterday.
        if !days.contains(day) { day -= 1 }
        var run = Run()
        var lastRest: Int?
        while true {
            if days.contains(day) {
                run.count += 1
                run.span += 1
                day -= 1
            } else if days.contains(day - 1), lastRest == nil || (lastRest! - day) >= 7 {
                // Exactly one missed day with a finished day before it: forgive it.
                if run.restDay == nil { run.restDay = day }
                lastRest = day
                run.span += 1
                day -= 1
            } else {
                break
            }
        }
        return run
    }

    /// Days in a row ending today (or yesterday, if today has no session yet), forgiving a single rest day.
    static func current(now: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Int {
        run(now: now, calendar: calendar, defaults: defaults).count
    }

    /// True when a rest day saved the streak within the last week (for a kind line on the streak screen).
    static func usedRestDayRecently(now: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Bool {
        guard let rest = run(now: now, calendar: calendar, defaults: defaults).restDay else { return false }
        return dayNumber(now, calendar) - rest <= 6
    }

    /// Five days for the little row: the streak start through the days after it. `done` marks finished days.
    static func week(now: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) -> [(label: String, done: Bool)] {
        let days = finishedDays(defaults)
        let today = dayNumber(now, calendar)
        let span = max(run(now: now, calendar: calendar, defaults: defaults).span, 1)
        let start = today - (min(span, 5) - 1)
        let symbols = calendar.shortWeekdaySymbols
        return (0..<5).map { offset in
            let number = start + offset
            let date = calendar.date(byAdding: .day, value: number - today, to: now) ?? now
            let weekday = calendar.component(.weekday, from: date)
            return (symbols[(weekday - 1) % symbols.count], days.contains(number))
        }
    }
}
