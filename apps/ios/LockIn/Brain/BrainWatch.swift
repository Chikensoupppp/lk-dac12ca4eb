import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import WidgetKit

/// Sets up the daily watch behind the brain widget: one all-day, repeating Device Activity with an
/// event at each hour line for the apps the user picked, plus 2 h and 3 h lines for each single app.
/// It watches the same apps the user chose to lock, because Apple only lets Lock In track apps
/// the user picked. The monitor extension records crossed lines (see `BrainLevel`).
enum BrainWatch {
    private static let lastSelectionKey = "lockin.brain.watchedSelection.v1"

    /// Starts or refreshes watching. Cheap to call often: it only restarts when the picked apps
    /// changed or nothing is being watched, because a restart can recount the day on older iOS.
    @MainActor
    static func update(selection: FamilyActivitySelection, authorized: Bool) {
        let center = DeviceActivityCenter()
        let name = DeviceActivityName(BrainLevel.activityName)
        let empty = selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
        let defaults = UserDefaults.standard

        guard authorized, !empty else {
            if center.activities.contains(name) { center.stopMonitoring([name]) }
            defaults.removeObject(forKey: lastSelectionKey)
            setWatching(false)
            return
        }

        let encoded = try? JSONEncoder().encode(selection)
        if center.activities.contains(name), let encoded, encoded == defaults.data(forKey: lastSelectionKey) {
            setWatching(true)
            return
        }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for h in BrainLevel.totalHours {
            events[DeviceActivityEvent.Name(BrainLevel.totalEvent(h))] = event(
                apps: selection.applicationTokens, categories: selection.categoryTokens,
                domains: selection.webDomainTokens, hours: h)
        }
        for (i, token) in selection.applicationTokens.prefix(BrainLevel.maxWatchedApps).enumerated() {
            for h in BrainLevel.appHours {
                events[DeviceActivityEvent.Name(BrainLevel.appEvent(index: i, hours: h))] = event(
                    apps: [token], categories: [], domains: [], hours: h)
            }
        }
        let allDay = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                            intervalEnd: DateComponents(hour: 23, minute: 59),
                                            repeats: true)
        do {
            try center.startMonitoring(name, during: allDay, events: events)
            defaults.set(encoded, forKey: lastSelectionKey)
            setWatching(true)
        } catch {
            setWatching(false)
        }
    }

    /// On iOS 17.4+ an event also counts use from earlier today, so starting mid-day is accurate.
    private static func event(apps: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>,
                              domains: Set<WebDomainToken>, hours: Int) -> DeviceActivityEvent {
        let threshold = DateComponents(hour: hours)
        if #available(iOS 17.4, *) {
            return DeviceActivityEvent(applications: apps, categories: categories, webDomains: domains,
                                       threshold: threshold, includesPastActivity: true)
        }
        return DeviceActivityEvent(applications: apps, categories: categories, webDomains: domains, threshold: threshold)
    }

    private static func setWatching(_ on: Bool) {
        guard let shared = BrainLevel.shared else { return }
        if shared.bool(forKey: BrainLevel.watchingKey) != on {
            shared.set(on, forKey: BrainLevel.watchingKey)
            WidgetCenter.shared.reloadTimelines(ofKind: BrainLevel.widgetKind)
        }
    }
}
