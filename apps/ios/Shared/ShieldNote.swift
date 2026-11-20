import Foundation

/// What SwipeLater's own block screen says (mock: docs/design/ios-block-screen.html, option A).
/// The app (and the monitor, for Plus "Lock by itself") writes when the shields come off and
/// whether the session is Locked; the shield extensions read it from the app group. Foundation
/// only, so the app, the extensions and the tests share it.
enum ShieldNote {
    static let endsAtKey = "lockin.shield.endsAt.v1"
    static let lockedKey = "lockin.shield.locked.v1"
    /// The "Swipe it later" reminder, so a second tap replaces it instead of adding another.
    static let reminderID = "lockin.shield.swipe-later"

    struct Now: Equatable {
        let endsAt: Date
        let locked: Bool
    }

    static func save(endsAt: Date, locked: Bool, defaults: UserDefaults? = BrainLevel.shared) {
        defaults?.set(endsAt.timeIntervalSince1970, forKey: endsAtKey)
        defaults?.set(locked, forKey: lockedKey)
    }

    static func clear(defaults: UserDefaults? = BrainLevel.shared) {
        defaults?.removeObject(forKey: endsAtKey)
        defaults?.removeObject(forKey: lockedKey)
    }

    /// The running session, or nil when nothing was saved or it already ended.
    static func current(now: Date = .now, defaults: UserDefaults? = BrainLevel.shared) -> Now? {
        guard let defaults, let seconds = defaults.object(forKey: endsAtKey) as? Double else { return nil }
        let endsAt = Date(timeIntervalSince1970: seconds)
        guard endsAt > now else { return nil }
        return Now(endsAt: endsAt, locked: defaults.bool(forKey: lockedKey))
    }

    // MARK: Words

    /// "Instagram can wait." / "Locked till 4:25."
    static func title(appName: String?, session: Now?, timeStyle: (Date) -> String = ShieldNote.clockTime) -> String {
        if let session, session.locked { return "Locked till \(timeStyle(session.endsAt))." }
        let name = appName.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        return "\(name ?? "This") can wait."
    }

    static func subtitle(session: Now?, now: Date = .now) -> String {
        if let session, session.locked { return "No way out this time.\nThat was the deal." }
        guard let session else { return "You\u{2019}re locked in.\nIt\u{2019}ll still be here after." }
        return "You\u{2019}re locked in. \(left(session.endsAt.timeIntervalSince(now))).\nIt\u{2019}ll still be here after."
    }

    /// "18 min left", "1 h 5 min left", "Less than a minute left".
    static func left(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes <= 1 { return seconds < 60 ? "Less than a minute left" : "1 min left" }
        if minutes < 60 { return "\(minutes) min left" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h left" : "\(h) h \(m) min left"
    }

    static let primaryButton = "Back to focus"
    static let secondaryButton = "Swipe it later"

    static func clockTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
