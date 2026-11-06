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

    /// Days in a row ending today. If today has no session yet, a streak ending yesterday still counts.
    static func current(now: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) -> Int {
        let days = finishedDays(defaults)
        var day = dayNumber(now, calendar)
        if !days.contains(day) { day -= 1 }
        var count = 0
        while days.contains(day) {
            count += 1
            day -= 1
        }
        return count
    }

    /// Five days for the little row: the streak start through the days after it. `done` marks finished days.
    static func week(now: Date = .now, calendar: Calendar = .current, defaults: UserDefaults = .standard) -> [(label: String, done: Bool)] {
        let days = finishedDays(defaults)
        let today = dayNumber(now, calendar)
        let streak = max(current(now: now, calendar: calendar, defaults: defaults), 1)
        let start = today - (min(streak, 5) - 1)
        let symbols = calendar.shortWeekdaySymbols
        return (0..<5).map { offset in
            let number = start + offset
            let date = calendar.date(byAdding: .day, value: number - today, to: now) ?? now
            let weekday = calendar.component(.weekday, from: date)
            return (symbols[(weekday - 1) % symbols.count], days.contains(number))
        }
    }
}
