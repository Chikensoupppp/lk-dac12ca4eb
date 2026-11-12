import Foundation
import WidgetKit

/// Rules for leaving a session early.
///
/// Free: you can always quit, but it costs you. A wait that only counts while you watch it (and
/// grows each time this week: 1, 5, then 15 minutes), a sentence you type, and a scar on the
/// widget brain until tomorrow morning.
/// Plus "Locked" sessions have no quit button. The ways out are a Key Holder (in person, or a
/// remote ask through iCloud) or one emergency exit a week with a 15-minute watched wait.
enum QuitRules {
    static let sentence = "I'm choosing my phone over my goal"
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

    /// The watched wait for the next free quit: 1 minute, then 5, then 15.
    static func nextQuitWait(_ defaults: UserDefaults = .standard) -> TimeInterval {
        switch quitsThisWeek(defaults) {
        case 0: return 60
        case 1: return 5 * 60
        default: return 15 * 60
        }
    }

    /// Records an early end: counts it for the week and scars today's widget brain.
    static func recordEarlyEnd(_ defaults: UserDefaults = .standard) {
        let count = quitsThisWeek(defaults) + 1
        defaults.set(weekKey(), forKey: weekKeyKey)
        defaults.set(count, forKey: weekQuitsKey)
        BrainLevel.markScar()
        WidgetCenter.shared.reloadTimelines(ofKind: BrainLevel.widgetKind)
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

    /// Does the typed text match the sentence? Case, spaces and the end period do not matter.
    static func matches(_ typed: String) -> Bool {
        func clean(_ s: String) -> String {
            s.lowercased()
                .replacingOccurrences(of: "\u{2019}", with: "'")
                .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!")))
        }
        return clean(typed) == clean(sentence)
    }
}
