import Foundation

/// Lock In's own record of focus, per day: minutes from finished sessions, how many finished,
/// and how many were quit early. Goals, reminders and the Sunday report read only this.
/// (Apple's Screen Time numbers cannot be read by the app, so they are never used here.)
/// Weeks run Monday to Sunday, so the Sunday report closes the week.
enum FocusLog {
    struct Day: Codable, Equatable {
        var minutes = 0
        var sessions = 0
        var quits = 0
    }

    struct Week: Equatable {
        let start: Date
        /// Monday first.
        let days: [Day]
        var minutes: Int { days.reduce(0) { $0 + $1.minutes } }
        var sessions: Int { days.reduce(0) { $0 + $1.sessions } }
        var quits: Int { days.reduce(0) { $0 + $1.quits } }
        var isEmpty: Bool { minutes == 0 && sessions == 0 && quits == 0 }
        /// Index of the day with the most minutes, or nil when nothing was focused.
        var bestDay: Int? {
            guard let best = days.indices.max(by: { days[$0].minutes < days[$1].minutes }),
                  days[best].minutes > 0 else { return nil }
            return best
        }
    }

    static let key = "lockin.focusLog.v1"

    static let calendar: Calendar = {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }()

    static func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func weekStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func weekKey(_ date: Date) -> String { dayKey(weekStart(date)) }

    private static func load(_ defaults: UserDefaults) -> [String: Day] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: Day].self, from: data)) ?? [:]
    }

    private static func update(_ date: Date, _ defaults: UserDefaults, _ change: (inout Day) -> Void) {
        var all = load(defaults)
        var day = all[dayKey(date)] ?? Day()
        change(&day)
        all[dayKey(date)] = day
        // Keep about 10 weeks; the report only looks back one.
        let cutoff = dayKey(calendar.date(byAdding: .day, value: -70, to: date) ?? date)
        all = all.filter { $0.key >= cutoff }
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: key) }
    }

    static func recordFinished(minutes: Int, at date: Date = .now, defaults: UserDefaults = .standard) {
        update(date, defaults) { $0.minutes += max(minutes, 0); $0.sessions += 1 }
    }

    static func recordQuit(at date: Date = .now, defaults: UserDefaults = .standard) {
        update(date, defaults) { $0.quits += 1 }
    }

    static func week(of date: Date, defaults: UserDefaults = .standard) -> Week {
        let all = load(defaults)
        let start = weekStart(date)
        let days = (0..<7).map { offset -> Day in
            let d = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return all[dayKey(d)] ?? Day()
        }
        return Week(start: start, days: days)
    }

    /// "4 h 20", "45 min", "2 h".
    static func format(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
    }
}
