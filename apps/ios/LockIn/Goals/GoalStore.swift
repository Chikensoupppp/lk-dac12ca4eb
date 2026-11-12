import Foundation
import UserNotifications

/// The weekly focus goal (2 to 8 hours of finished sessions), the reminder switches, and which
/// Sunday reports were already seen. A goal is stored per week, so changing next week's goal
/// from the report never rewrites the week being reported.
@MainActor
final class GoalStore: ObservableObject {
    static let range = 2...8
    static let suggested = 4

    private let defaults: UserDefaults
    private static let goalsKey = "lockin.goal.byWeek.v1"
    private static let remindKey = "lockin.goal.remind.v1"
    private static let weekdaysKey = "lockin.goal.weekdaysOnly.v1"
    private static let seenKey = "lockin.report.seen.v1"

    @Published private(set) var byWeek: [String: Int]
    @Published var remindersOn: Bool { didSet { defaults.set(remindersOn, forKey: Self.remindKey); reschedule() } }
    @Published var weekdaysOnly: Bool { didSet { defaults.set(weekdaysOnly, forKey: Self.weekdaysKey); reschedule() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        byWeek = defaults.dictionary(forKey: Self.goalsKey) as? [String: Int] ?? [:]
        remindersOn = defaults.bool(forKey: Self.remindKey)
        weekdaysOnly = defaults.bool(forKey: Self.weekdaysKey)
    }

    /// The goal in force for the week holding `date`: that week's own goal, else the latest
    /// one set before it. Nil until the user sets a first goal.
    func goal(forWeekOf date: Date = .now) -> Int? {
        let key = FocusLog.weekKey(date)
        guard let latest = byWeek.keys.filter({ $0 <= key }).max() else { return nil }
        return byWeek[latest]
    }

    func setGoal(_ hours: Int, forWeekOf date: Date = .now) {
        byWeek[FocusLog.weekKey(date)] = min(max(hours, Self.range.lowerBound), Self.range.upperBound)
        defaults.set(byWeek, forKey: Self.goalsKey)
        reschedule()
    }

    // MARK: Reminders

    /// Asks iPhone for notification permission. The goal page explains the reminders first.
    func turnRemindersOn() async {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        remindersOn = granted
    }

    func reschedule(now: Date = .now) {
        GoalReminders.schedule(goal: goal(forWeekOf: now), on: remindersOn, weekdaysOnly: weekdaysOnly, now: now)
    }

    // MARK: Sunday report

    /// The week whose report should open now, if any: this week from Sunday 6 PM, otherwise
    /// last week. Only once per week, and only for a week with a goal or some focus in it.
    func pendingReport(now: Date = .now) -> Date? {
        let cal = FocusLog.calendar
        let thisWeek = FocusLog.weekStart(now)
        let sundayEvening = cal.component(.weekday, from: now) == 1 && cal.component(.hour, from: now) >= GoalReminders.reportHour
        guard let week = sundayEvening ? thisWeek : cal.date(byAdding: .day, value: -7, to: thisWeek) else { return nil }
        let seen = Set(defaults.stringArray(forKey: Self.seenKey) ?? [])
        guard !seen.contains(FocusLog.weekKey(week)) else { return nil }
        guard goal(forWeekOf: week) != nil || !FocusLog.week(of: week).isEmpty else { return nil }
        return week
    }

    func markSeen(_ week: Date) {
        var seen = defaults.stringArray(forKey: Self.seenKey) ?? []
        seen.append(FocusLog.weekKey(week))
        defaults.set(Array(seen.suffix(20)), forKey: Self.seenKey)
    }
}

/// Local notifications only; nothing leaves the phone. Progress comes from `FocusLog`, which
/// only changes when a session ends in the app, so rescheduling then keeps the text right.
enum GoalReminders {
    static let nudgeHour = 17
    static let reportHour = 18
    private static let nudgePrefix = "lockin.goal.nudge."
    private static let reportID = "lockin.report.sunday"

    static func schedule(goal: Int?, on: Bool, weekdaysOnly: Bool, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(nudgePrefix) || $0 == reportID }
            center.removePendingNotificationRequests(withIdentifiers: old)
            guard on else { return }

            // Sunday report: no numbers in the text, the report itself has them.
            let report = UNMutableNotificationContent()
            report.title = "Your week is ready"
            report.body = "See how your focus went this week."
            report.sound = .default
            center.add(UNNotificationRequest(identifier: reportID, content: report,
                trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: reportHour, minute: 0, weekday: 1), repeats: true)))

            guard let goal else { return }
            let cal = FocusLog.calendar
            let done = FocusLog.week(of: now).minutes
            let goalMinutes = goal * 60
            guard done < goalMinutes else { return }
            let percent = done * 100 / goalMinutes
            let start = FocusLog.weekStart(now)
            for offset in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: offset, to: start),
                      let fire = cal.date(bySettingHour: nudgeHour, minute: 0, second: 0, of: day),
                      fire > now else { continue }
                let weekday = cal.component(.weekday, from: day)
                if weekdaysOnly && (weekday == 1 || weekday == 7) { continue }
                let content = UNMutableNotificationContent()
                content.title = "Lock In"
                content.body = nudgeText(percent: percent, goal: goal, left: goalMinutes - done, lastDay: weekday == 1)
                content.sound = .default
                let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                center.add(UNNotificationRequest(identifier: nudgePrefix + FocusLog.dayKey(day), content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
            }
        }
    }

    static func nudgeText(percent: Int, goal: Int, left: Int, lastDay: Bool) -> String {
        if percent == 0 { return "Your goal this week is \(goal) hours. One session gets it moving." }
        if lastDay { return "Last day. You're \(percent)% of the way to \(goal) hours. \(FocusLog.format(minutes: left)) to go." }
        return "You're \(percent)% of the way to your \(goal)-hour goal. \(FocusLog.format(minutes: left)) to go."
    }
}
