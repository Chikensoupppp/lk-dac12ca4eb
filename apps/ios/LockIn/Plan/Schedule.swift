import DeviceActivity
import FamilyControls
import Foundation
import UserNotifications

/// What happens at the plan's time, chosen on "When works for you?". Stays on this phone.
struct LockInSchedule: Codable, Equatable {
    enum Then: String, Codable { case remind, autoLock }

    /// A reminder (free) or the apps locking by themselves (Plus).
    var then: Then

    static let key = "lockin.schedule.v1"

    static func load(_ defaults: UserDefaults = .standard) -> LockInSchedule? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(LockInSchedule.self, from: $0) }
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}

/// Free "Remind me": one repeating notification per plan day at that day's time. Local only.
enum PlanReminders {
    static let idPrefix = "lockin.planNudge."

    static func turnOn(plan: LockInPlan) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        turnOff()
        for weekday in plan.weekdays {
            let minute = plan.startMinute(weekday: weekday)
            let content = UNMutableNotificationContent()
            content.title = "Time to lock in"
            content.body = plan.task.map { "\($0), \(plan.minutes) minutes. One hold and you are in." }
                ?? "\(plan.minutes) minutes. One hold and you are in."
            content.sound = .default
            let when = DateComponents(hour: minute / 60, minute: minute % 60, weekday: weekday)
            try? await center.add(UNNotificationRequest(identifier: idPrefix + String(weekday), content: content,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
        }
        return true
    }

    static func turnOff() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (1...7).map { idPrefix + String($0) })
    }
}

/// Plus "Lock by itself": one repeating Device Activity schedule per plan day. The monitor
/// extension shields the picked apps when each one starts (see `AutoLock`).
enum AutoLockScheduler {
    static func turnOn(plan: LockInPlan, selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) { BrainLevel.shared?.set(data, forKey: AutoLock.selectionKey) }
        turnOff()
        let center = DeviceActivityCenter()
        let length = max(plan.minutesPerDay, Int(RestrictionNaming.minimumMonitoringInterval / 60))
        for weekday in plan.weekdays {
            let start = plan.startMinute(weekday: weekday)
            let end = min(start + length, 24 * 60 - 1)
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: start / 60, minute: start % 60, weekday: weekday),
                intervalEnd: DateComponents(hour: end / 60, minute: end % 60, weekday: weekday),
                repeats: true)
            try? center.startMonitoring(DeviceActivityName(AutoLock.activityName(weekday: weekday, startMinute: start,
                                                                                minutes: plan.minutesPerDay)),
                                        during: schedule)
        }
    }

    static func turnOff() {
        let center = DeviceActivityCenter()
        let ours = center.activities.filter { AutoLock.isAuto($0.rawValue) }
        if !ours.isEmpty { center.stopMonitoring(ours) }
    }

    static var isOn: Bool { DeviceActivityCenter().activities.contains { AutoLock.isAuto($0.rawValue) } }
}

/// Turns the chosen schedule on after the first run (or when it changes): either the Plus
/// auto-lock (when Plus is active and apps are picked) or reminders.
enum ScheduleApplier {
    @MainActor
    static func apply(plan: LockInPlan, schedule: LockInSchedule, hasPlus: Bool, restrictions: RestrictionController) async {
        if schedule.then == .autoLock, hasPlus, restrictions.hasSelection {
            PlanReminders.turnOff()
            AutoLockScheduler.turnOn(plan: plan, selection: restrictions.selection)
        } else {
            AutoLockScheduler.turnOff()
            _ = await PlanReminders.turnOn(plan: plan)
        }
    }
}
