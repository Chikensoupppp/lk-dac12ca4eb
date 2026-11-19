import DeviceActivity
import EventKit
import FamilyControls
import Foundation
import UserNotifications

/// What happens at the plan's time, chosen on the "Can't do 4:00?" screens. Stays on this phone.
struct LockInSchedule: Codable, Equatable {
    enum Then: String, Codable { case remind, autoLock }

    /// A reminder (free) or the apps locking by themselves (Plus).
    var then: Then
    /// Put the lock-ins on the user's calendar as SwipeLater's own repeating events.
    var addToCalendar: Bool

    static let key = "lockin.schedule.v1"

    static func load(_ defaults: UserDefaults = .standard) -> LockInSchedule? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(LockInSchedule.self, from: $0) }
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}

/// The user's calendar, read on the phone only. It reads when events are and what they are
/// called (so a surgery day stays free); nothing is saved or sent. It writes only SwipeLater's
/// own lock-in events, and only when the user turns "Add to my calendar" on.
enum CalendarAccess {
    enum State { case notAsked, allowed, refused }

    private static let store = EKEventStore()
    private static let eventIDsKey = "lockin.schedule.eventIDs.v1"
    static let eventTitle = "SwipeLater lock-in"

    static var state: State {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notAsked
        case .fullAccess, .authorized: return .allowed
        default: return .refused
        }
    }

    /// Shows Apple's calendar box (once). True when access was given.
    static func ask() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Events from today through the next 8 days, as plain busy blocks.
    static func busy(from now: Date = .now) -> [CalendarFit.Busy] {
        guard state == .allowed else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .day, value: 8, to: start) else { return [] }
        let ours = Set(savedEventIDs())
        return store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            .filter { !ours.contains($0.eventIdentifier ?? "") && $0.availability != .free }
            .map { CalendarFit.Busy(start: $0.startDate, end: $0.endDate, title: $0.title ?? "", allDay: $0.isAllDay) }
    }

    /// Replaces SwipeLater's lock-in events with one weekly repeating event per start time.
    static func writeLockIns(plan: LockInPlan, now: Date = .now) {
        removeLockIns()
        guard state == .allowed, let target = store.defaultCalendarForNewEvents else { return }
        let cal = Calendar.current
        let byStart = Dictionary(grouping: plan.weekdays, by: { plan.startMinute(weekday: $0) })
        var ids: [String] = []
        for (start, weekdays) in byStart {
            guard let first = nextDate(weekdays: weekdays, minute: start, after: now, calendar: cal) else { continue }
            let event = EKEvent(eventStore: store)
            event.title = eventTitle
            event.calendar = target
            event.startDate = first
            event.endDate = first.addingTimeInterval(Double(plan.minutesPerDay) * 60)
            event.notes = "Set by SwipeLater. Change it in the app."
            let days = weekdays.sorted().compactMap { EKWeekday(rawValue: $0) }.map { EKRecurrenceDayOfWeek($0) }
            event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, daysOfTheWeek: days,
                                                      daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
                                                      daysOfTheYear: nil, setPositions: nil, end: nil)]
            if (try? store.save(event, span: .futureEvents)) != nil, let id = event.eventIdentifier { ids.append(id) }
        }
        UserDefaults.standard.set(ids, forKey: eventIDsKey)
    }

    /// Removes only the events SwipeLater added.
    static func removeLockIns() {
        for id in savedEventIDs() {
            if let event = store.event(withIdentifier: id) { try? store.remove(event, span: .futureEvents) }
        }
        UserDefaults.standard.removeObject(forKey: eventIDsKey)
    }

    private static func savedEventIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: eventIDsKey) ?? []
    }

    private static func nextDate(weekdays: [Int], minute: Int, after now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let start = calendar.date(byAdding: .minute, value: minute, to: day), start > now else { continue }
            return start
        }
        return nil
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

/// Turns the chosen schedule on after the first run (or when it changes): calendar events,
/// then either the Plus auto-lock (when Plus is active and apps are picked) or reminders.
enum ScheduleApplier {
    @MainActor
    static func apply(plan: LockInPlan, schedule: LockInSchedule, hasPlus: Bool, restrictions: RestrictionController) async {
        if schedule.addToCalendar { CalendarAccess.writeLockIns(plan: plan) } else { CalendarAccess.removeLockIns() }
        if schedule.then == .autoLock, hasPlus, restrictions.hasSelection {
            PlanReminders.turnOff()
            AutoLockScheduler.turnOn(plan: plan, selection: restrictions.selection)
        } else {
            AutoLockScheduler.turnOff()
            _ = await PlanReminders.turnOn(plan: plan)
        }
    }
}
