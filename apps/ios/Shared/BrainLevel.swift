import Foundation

/// How rotten the widget brain is today. Shared by the app, the monitor extension and the widget.
///
/// Lock In can never read Screen Time minutes. Instead the app asks Apple for threshold events
/// ("the watched apps reached 2 hours today", "one app reached 2 hours"); the monitor extension
/// records each one here, in the shared app group, and the widget reads them. So the widget knows
/// which lines were crossed, not exact minutes. Days are keyed by date, so a new day starts fresh.
enum BrainLevel {
    static let appGroup = "group.com.brandon132199.lockin"
    static let activityName = "lockin.brain.daily"
    static let widgetKind = "LockInBrain"
    /// Hours of use, across all watched apps, that each raise an event.
    static let totalHours = [1, 2, 3, 4, 5, 6, 7]
    /// Hours on one single app that raise an event.
    static let appHours = [2, 3]
    /// Apple caps how much one activity can watch; one app line per app, for the first few apps.
    static let maxWatchedApps = 10

    static let watchingKey = "brain.watching"

    static var shared: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func totalEvent(_ hours: Int) -> String { "total.\(hours)" }
    static func appEvent(index: Int, hours: Int) -> String { "app.\(index).\(hours)" }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Records one threshold event. Returns true when today's level went up.
    @discardableResult
    static func record(event: String, now: Date = .now, defaults: UserDefaults? = shared) -> Bool {
        guard let defaults else { return false }
        let parts = event.split(separator: ".")
        let day = dayKey(now)
        if parts.count == 2, parts[0] == "total", let h = Int(parts[1]) {
            return raise("brain.\(day).total", to: h, in: defaults)
        }
        if parts.count == 3, parts[0] == "app", let h = Int(parts[2]) {
            return raise("brain.\(day).app", to: h, in: defaults)
        }
        return false
    }

    private static func raise(_ key: String, to value: Int, in defaults: UserDefaults) -> Bool {
        guard value > defaults.integer(forKey: key) else { return false }
        defaults.set(value, forKey: key)
        return true
    }

    struct Today: Equatable {
        /// Highest whole hour reached across watched apps today (0 = under 1 hour).
        var total: Int
        /// Highest whole hour one single app reached today (0 = none over 2 hours).
        var app: Int

        /// 0 fresh, 1 tired, 2 dizzy, 3 fading, 4 begging, 5 rotten. One heavy app makes it one worse.
        var stage: Int {
            let base: Int
            switch total {
            case 7...: base = 5
            case 5...: base = 4
            case 4: base = 3
            case 2...: base = 2
            case 1: base = 1
            default: base = 0
            }
            return min(5, base + (app >= 2 ? 1 : 0))
        }

        var headline: String { total == 0 ? "UNDER 1H" : "\(total)H+" }

        var appLine: String? { app >= 2 ? "One app hit \(app)h today" : nil }
    }

    static func today(now: Date = .now, defaults: UserDefaults? = shared) -> Today {
        let day = dayKey(now)
        return Today(total: defaults?.integer(forKey: "brain.\(day).total") ?? 0,
                     app: defaults?.integer(forKey: "brain.\(day).app") ?? 0)
    }

    /// Whether the app has set up watching (Screen Time on and apps picked).
    static func isWatching(defaults: UserDefaults? = shared) -> Bool {
        defaults?.bool(forKey: watchingKey) ?? false
    }
}
