import Foundation

/// Plus "Lock by itself": the picked apps lock at the plan's time on the plan's days, every week,
/// without opening the app. The app registers one repeating Device Activity schedule per day; the
/// monitor extension applies the shield when an interval starts and clears it when it ends.
/// Shared by the app, the monitor extension and the tests (Foundation only).
enum AutoLock {
    static let activityPrefix = "lockin.auto."
    /// The picked apps, copied into the app group so the extension can shield them.
    static let selectionKey = "lockin.autolock.selection.v1"

    /// "lockin.auto.<weekday>.<startMinute>.<minutes>", weekday 1 = Sunday ... 7 = Saturday.
    static func activityName(weekday: Int, startMinute: Int, minutes: Int) -> String {
        "\(activityPrefix)\(weekday).\(startMinute).\(minutes)"
    }

    static func parse(_ name: String) -> (weekday: Int, startMinute: Int, minutes: Int)? {
        guard name.hasPrefix(activityPrefix) else { return nil }
        let parts = name.dropFirst(activityPrefix.count).split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3, (1...7).contains(parts[0]) else { return nil }
        return (parts[0], parts[1], parts[2])
    }

    static func isAuto(_ name: String) -> Bool { parse(name) != nil }

    /// An auto-lock that ends must not clear shields a hand-started session still needs.
    /// `monitored` is every activity registered with the system.
    static func mayClear(monitored: [String], now: Date) -> Bool {
        !monitored.contains { name in
            guard let session = RestrictionNaming.parse(name) else { return false }
            return session.endsAt > now
        }
    }
}
