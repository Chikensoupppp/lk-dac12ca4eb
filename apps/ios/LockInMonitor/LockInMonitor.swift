import DeviceActivity
import ManagedSettings
import WidgetKit

/// Two jobs.
/// 1. Backup cleanup. The app removes shields itself when a session ends; this covers the case
///    where the app was terminated. Apple only invokes `intervalDidEnd` while the device is in use,
///    so removal can lag the session end. The extension never applies shields.
/// 2. The widget brain. Apple tells this extension when the watched apps cross an hour line today;
///    it records that in the app group and refreshes the widget (see `BrainLevel`).
final class LockInMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        clearIfDue(activity)
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
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

    private func clearIfDue(_ activity: DeviceActivityName) {
        let monitored = DeviceActivityCenter().activities.map(\.rawValue)
        guard RestrictionNaming.shouldClearShield(
            endedActivity: activity.rawValue, monitored: monitored, now: .now
        ) else { return }
        ManagedSettingsStore(named: .init(RestrictionNaming.storeName)).clearAllSettings()
    }
}
