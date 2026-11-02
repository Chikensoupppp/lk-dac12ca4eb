import Foundation

/// Names and cleanup rules shared by the app and the Device Activity monitor extension.
/// Pure Foundation so both targets, and the unit tests, can use it.
enum RestrictionNaming {
    /// Named `ManagedSettingsStore`. Lock In writes shields only here, so clearing it
    /// never touches settings owned by anything else.
    static let storeName = "lockin.focus"
    static let activityPrefix = "lockin.session."

    /// Apple's documented minimum Device Activity interval (`MonitoringError.intervalTooShort`).
    static let minimumMonitoringInterval: TimeInterval = 15 * 60
    /// The backup interval ends slightly after the session so rounding to whole seconds can
    /// never drop it under the minimum, and so it never fires before the in-app timer.
    static let cleanupBuffer: TimeInterval = 30

    static func activityName(sessionID: UUID, endsAt: Date) -> String {
        "\(activityPrefix)\(sessionID.uuidString).\(Int(endsAt.timeIntervalSince1970.rounded(.up)))"
    }

    static func parse(_ name: String) -> (id: UUID, endsAt: Date)? {
        guard name.hasPrefix(activityPrefix) else { return nil }
        let parts = name.dropFirst(activityPrefix.count).split(separator: ".")
        guard parts.count == 2,
              let id = UUID(uuidString: String(parts[0])),
              let seconds = TimeInterval(parts[1])
        else { return nil }
        return (id, Date(timeIntervalSince1970: seconds))
    }

    /// Decides whether an `intervalDidEnd` callback may clear the shield store.
    /// `monitored` is every activity currently registered with the system.
    /// Ignores foreign activities, early callbacks, and callbacks from an older session
    /// when a newer session is still being monitored.
    static func shouldClearShield(endedActivity: String, monitored: [String], now: Date) -> Bool {
        guard let ended = parse(endedActivity) else { return false }
        guard now >= ended.endsAt else { return false }
        for other in monitored where other != endedActivity {
            if let newer = parse(other), newer.endsAt > ended.endsAt { return false }
        }
        return true
    }
}
