import DeviceActivity
import ManagedSettings

/// Backup cleanup. The app removes shields itself when a session ends; this covers the
/// case where the app was terminated. Apple only invokes `intervalDidEnd` while the device
/// is in use, so removal can lag the session end. The extension never applies shields.
final class LockInMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        clearIfDue(activity)
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // If the system delivers a start for an interval that already finished, clean up.
        clearIfDue(activity)
    }

    private func clearIfDue(_ activity: DeviceActivityName) {
        let monitored = DeviceActivityCenter().activities.map(\.rawValue)
        guard RestrictionNaming.shouldClearShield(
            endedActivity: activity.rawValue, monitored: monitored, now: .now
        ) else { return }
        ManagedSettingsStore(named: .init(RestrictionNaming.storeName)).clearAllSettings()
    }
}
