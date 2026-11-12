import ActivityKit
import Foundation

/// The lock screen and Dynamic Island countdown. Shared by the app (starts and ends it) and the
/// widget extension (draws it). The countdown is drawn by the system from `endsAt`, so the app
/// never has to send updates while the session runs.
struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endsAt: Date
        /// Plus Locked session: no quit button.
        var locked: Bool
    }

    var sessionID: String
    var startedAt: Date
}
