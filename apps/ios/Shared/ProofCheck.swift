import Foundation

/// Proof Check: notices when Screen Time access for Lock In was turned off in Settings. That is
/// the one way to drop the shields without going through the app. Apple does not tell Lock In
/// when it happens, so the app checks each time it opens or comes back to the front.
/// The result lives in the app group so the brain widget can show it too.
enum ProofCheck {
    private static let wasOnKey = "proof.wasOn"
    private static let offSinceKey = "proof.offSince"

    enum Change: Equatable { case none, turnedOff, turnedOn }

    /// Feed the current access state. Reports a change only once per switch, so repeated calls
    /// are safe. "Off" only counts if access was on before (a new user who never allowed it
    /// is not cheating).
    static func update(approved: Bool, now: Date = .now, defaults: UserDefaults? = BrainLevel.shared) -> Change {
        guard let defaults else { return .none }
        if approved {
            let wasOff = defaults.object(forKey: offSinceKey) != nil
            defaults.set(true, forKey: wasOnKey)
            defaults.removeObject(forKey: offSinceKey)
            return wasOff ? .turnedOn : .none
        }
        guard defaults.bool(forKey: wasOnKey), defaults.object(forKey: offSinceKey) == nil else { return .none }
        defaults.set(now, forKey: offSinceKey)
        return .turnedOff
    }

    static func offSince(defaults: UserDefaults? = BrainLevel.shared) -> Date? {
        defaults?.object(forKey: offSinceKey) as? Date
    }
}
