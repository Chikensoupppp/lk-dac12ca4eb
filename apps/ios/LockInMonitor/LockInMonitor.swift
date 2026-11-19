import DeviceActivity
import FamilyControls
import ManagedSettings
import WidgetKit

/// Three jobs.
/// 1. Backup cleanup. The app removes shields itself when a session ends; this covers the case
///    where the app was terminated. Apple only invokes `intervalDidEnd` while the device is in use,
///    so removal can lag the session end.
/// 3. Plus "Lock by itself" (`AutoLock`): the only time this extension applies shields, at the
///    start of a repeating auto-lock interval, and clears them at its end.
/// 2. The widget brain. Apple tells this extension when the watched apps cross an hour line today;
///    it records that in the app group and refreshes the widget (see `BrainLevel`).
final class LockInMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if AutoLock.isAuto(activity.rawValue) {
            let monitored = DeviceActivityCenter().activities.map(\.rawValue)
            if AutoLock.mayClear(monitored: monitored, now: .now) {
                ManagedSettingsStore(named: .init(RestrictionNaming.storeName)).clearAllSettings()
            }
            return
        }
        clearIfDue(activity)
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if AutoLock.isAuto(activity.rawValue) {
            applyAutoLock()
            return
        }
        if activity.rawValue == BrainLevel.activityName {
            // A new day: the brain starts fresh (levels are stored per date).
            WidgetCenter.shared.reloadTimelines(ofKind: BrainLevel.widgetKind)
            return
        }
        // If the system delivers a start for an interval that already finished, clean up.
        clearIfDue(activity)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity.rawValue == BrainLevel.activityName else { return }
        if BrainLevel.record(event: event.rawValue) {
            WidgetCenter.shared.reloadTimelines(ofKind: BrainLevel.widgetKind)
        }
    }

    /// Plus "Lock by itself": shield the apps the user picked (copied into the app group by the app).
    private func applyAutoLock() {
        guard let data = BrainLevel.shared?.data(forKey: AutoLock.selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        let store = ManagedSettingsStore(named: .init(RestrictionNaming.storeName))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    private func clearIfDue(_ activity: DeviceActivityName) {
        let monitored = DeviceActivityCenter().activities.map(\.rawValue)
        guard RestrictionNaming.shouldClearShield(
            endedActivity: activity.rawValue, monitored: monitored, now: .now
        ) else { return }
        ManagedSettingsStore(named: .init(RestrictionNaming.storeName)).clearAllSettings()
    }
}
