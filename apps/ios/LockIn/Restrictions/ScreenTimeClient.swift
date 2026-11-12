import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum ScreenTimeAuthorization: Equatable {
    case notDetermined
    case denied
    case approved
}

/// The only place that touches Apple's Screen Time frameworks, so the lifecycle logic in
/// `RestrictionController` can be tested with a fake.
@MainActor
protocol ScreenTimeClient: AnyObject {
    var authorization: ScreenTimeAuthorization { get }
    func requestAuthorization() async throws
    func startMonitoring(activity: String, from: Date, to: Date) throws
    func stopMonitoring()
    func applyShield(_ selection: FamilyActivitySelection)
    /// Locked mode: no deleting apps (Lock In included) and no changing the clock. Cleared with
    /// the shield. Apple notes it is not guaranteed under individual authorization: turning off
    /// Lock In's Screen Time access in Settings removes it (a Screen Time passcode stops that).
    func applyLock(_ on: Bool)
    func clearShield()
}

extension ScreenTimeClient {
    func applyLock(_ on: Bool) {}
}

@MainActor
final class SystemScreenTimeClient: ScreenTimeClient {
    private let store = ManagedSettingsStore(named: .init(RestrictionNaming.storeName))
    private let center = DeviceActivityCenter()

    var authorization: ScreenTimeAuthorization {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: return .approved
        case .denied: return .denied
        default: return .notDetermined
        }
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    func startMonitoring(activity: String, from: Date, to: Date) throws {
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let calendar = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: from),
            intervalEnd: calendar.dateComponents(fields, from: to),
            repeats: false
        )
        try center.startMonitoring(DeviceActivityName(activity), during: schedule)
    }

    func stopMonitoring() {
        // An empty list would stop every activity; only ever stop our own.
        let ours = center.activities.filter { $0.rawValue.hasPrefix(RestrictionNaming.activityPrefix) }
        guard !ours.isEmpty else { return }
        center.stopMonitoring(ours)
    }

    func applyShield(_ selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    func applyLock(_ on: Bool) {
        store.application.denyAppRemoval = on ? true : nil
        store.dateAndTime.requireAutomaticDateAndTime = on ? true : nil
    }

    func clearShield() {
        store.clearAllSettings()
    }
}
