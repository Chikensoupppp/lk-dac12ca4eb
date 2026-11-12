import Foundation
import UserNotifications

/// TESTING ONLY: each new TestFlight build starts like a first install, so the whole first-run
/// experience can be checked again. App Store builds never reset.
/// Kept: Friend Key pairing (re-pairing needs two phones) and a session that is still running.
/// Screen Time access cannot be taken back by the app, so the check slide shows it as already on.
enum FreshStart {
    private static let buildKey = "lockin.freshStart.build.v1"
    private static let keep: Set<String> = [
        "lockin.keys.holders.v1", "lockin.keys.friends.v1", "lockin.keys.name.v1", "lockin.keys.id.v1",
    ]

    static func runIfNewBuild(defaults: UserDefaults = .standard) {
        guard PlusStore.isTestFlight else { return }
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let last = defaults.string(forKey: buildKey)
        defer { defaults.set(build, forKey: buildKey) }
        // No stored build means an install from before this check existed: reset that too.
        guard last != build else { return }
        guard defaults.data(forKey: UserDefaultsSessionStore.key) == nil else { return }

        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("lockin.") && !keep.contains(key) {
            defaults.removeObject(forKey: key)
        }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        // Shared with the widget: today's quit scar and the Proof Check state.
        if let shared = BrainLevel.shared {
            for key in shared.dictionaryRepresentation().keys where key.hasPrefix("proof.") || key.hasSuffix(".scar") {
                shared.removeObject(forKey: key)
            }
        }
    }
}
