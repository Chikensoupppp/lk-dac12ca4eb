import Foundation
import UserNotifications

/// An optional "same time tomorrow" reminder. Off until the user taps it on the finish card.
/// Local notification only; nothing leaves the phone. One repeating daily reminder at one time.
enum DailyNudge {
    private static let minuteKey = "lockin.dailyNudge.minute.v1"
    static let requestID = "lockin.dailyNudge"

    /// Minutes after midnight, or nil when the reminder is off.
    static func minuteOfDay(_ defaults: UserDefaults = .standard) -> Int? {
        defaults.object(forKey: minuteKey) as? Int
    }

    static var isOn: Bool { minuteOfDay() != nil }

    /// The time the session began, to the nearest 5 minutes ("same time tomorrow").
    static func suggestedMinute(finishedAt: Date = .now, focusedMinutes: Int, calendar: Calendar = .current) -> Int {
        let start = finishedAt.addingTimeInterval(-Double(max(focusedMinutes, 0)) * 60)
        let parts = calendar.dateComponents([.hour, .minute], from: start)
        let raw = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        let rounded = ((raw + 2) / 5) * 5
        return rounded % (24 * 60)
    }

    /// "3:40 PM" in the user's own format.
    static func timeText(minute: Int, calendar: Calendar = .current) -> String {
        let date = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Asks iPhone for permission, then schedules the daily reminder. Returns false when not allowed.
    static func turnOn(minute: Int, defaults: UserDefaults = .standard) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        schedule(minute: minute)
        defaults.set(minute, forKey: minuteKey)
        return true
    }

    static func turnOff(defaults: UserDefaults = .standard) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestID])
        defaults.removeObject(forKey: minuteKey)
    }

    private static func schedule(minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        let content = UNMutableNotificationContent()
        content.title = "SwipeLater"
        content.body = "Ready for a focus session? One hold and you are in."
        content.sound = .default
        let when = DateComponents(hour: minute / 60, minute: minute % 60)
        center.add(UNNotificationRequest(identifier: requestID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
    }
}

/// Optional "if-then" plan: "When <cue>, I lock in." Off unless the user switches it on.
enum IfThenPlan {
    static let onKey = "lockin.ifThen.on.v1"
    static let cueKey = "lockin.ifThen.cue.v1"
    static let maxLength = 40

    /// The line shown on the Focus screen, or nil when off or empty.
    static func line(on: Bool, cue: String) -> String? {
        let clean = cue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard on, !clean.isEmpty else { return nil }
        return "When \(clean), I lock in."
    }
}

/// Apps and sites that stay open on the PC during a session, kept per task ("" is no task).
/// The names go to the PC with the session start. The PC decides what each name matches.
enum AllowedApps {
    private static let key = "lockin.allowed.v1"
    static let maxEntries = 30
    static let maxLength = 40

    private static func all(_ defaults: UserDefaults) -> [String: [String]] {
        defaults.dictionary(forKey: key) as? [String: [String]] ?? [:]
    }

    static func list(for task: String?, defaults: UserDefaults = .standard) -> [String] {
        all(defaults)[task ?? ""] ?? []
    }

    /// Adds a name (trimmed, no duplicates, capped). Returns the new list.
    @discardableResult
    static func add(_ name: String, for task: String?, defaults: UserDefaults = .standard) -> [String] {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
        var map = all(defaults)
        var items = map[task ?? ""] ?? []
        guard !clean.isEmpty,
              !items.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }),
              items.count < maxEntries else { return items }
        items.append(clean)
        map[task ?? ""] = items
        defaults.set(map, forKey: key)
        return items
    }

    @discardableResult
    static func remove(_ name: String, for task: String?, defaults: UserDefaults = .standard) -> [String] {
        var map = all(defaults)
        var items = map[task ?? ""] ?? []
        items.removeAll { $0 == name }
        map[task ?? ""] = items
        defaults.set(map, forKey: key)
        return items
    }
}
