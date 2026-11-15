import Foundation

/// Rules for leaving a session early.
///
/// Free: you can always end a session. It takes one tap and the time you focused still counts.
/// Plus "Locked" sessions are strict on purpose (the user turns that on themselves) and have no quit button. The ways out are a Key Holder (in person, or a
/// remote ask through iCloud) or one emergency exit a week with a 15-minute watched wait.
enum QuitRules {
    static let emergencyWait: TimeInterval = 15 * 60
    /// After a Key Holder says yes from far away, the session ends after this cool-down.
    static let remoteCoolDown: TimeInterval = 10 * 60
    /// A remote ask nobody answers expires after this.
    static let remoteTimeout: TimeInterval = 30 * 60

    private static let weekQuitsKey = "lockin.quit.weekCount.v1"
    private static let weekKeyKey = "lockin.quit.week.v1"
    private static let emergencyWeekKey = "lockin.quit.emergencyWeek.v1"
    private static let lockedKey = "lockin.session.locked.v1"

    static func weekKey(_ date: Date = .now, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(c.yearForWeekOfYear ?? 0)-W\(c.weekOfYear ?? 0)"
    }

    /// Early quits already used this week (resets each week).
    static func quitsThisWeek(_ defaults: UserDefaults = .standard) -> Int {
        guard defaults.string(forKey: weekKeyKey) == weekKey() else { return 0 }
        return defaults.integer(forKey: weekQuitsKey)
    }

    /// Records an early end: counts it for the week. Nothing else happens to the user.
    static func recordEarlyEnd(_ defaults: UserDefaults = .standard) {
        let count = quitsThisWeek(defaults) + 1
        defaults.set(weekKey(), forKey: weekKeyKey)
        defaults.set(count, forKey: weekQuitsKey)
    }

    static func emergencyAvailable(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: emergencyWeekKey) != weekKey()
    }

    static func useEmergency(_ defaults: UserDefaults = .standard) {
        defaults.set(weekKey(), forKey: emergencyWeekKey)
    }

    // MARK: Which session is locked

    static func markLocked(_ sessionID: UUID?, _ defaults: UserDefaults = .standard) {
        if let sessionID { defaults.set(sessionID.uuidString, forKey: lockedKey) }
        else { defaults.removeObject(forKey: lockedKey) }
    }

    static func isLocked(_ sessionID: UUID?, _ defaults: UserDefaults = .standard) -> Bool {
        guard let sessionID else { return false }
        return defaults.string(forKey: lockedKey) == sessionID.uuidString
    }
}
