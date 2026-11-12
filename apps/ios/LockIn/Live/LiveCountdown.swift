import ActivityKit
import Foundation

/// Starts and ends the lock screen countdown. The session store stays the source of truth: this
/// only mirrors it. If the user turned Live Activities off in Settings, it does nothing.
@MainActor
enum LiveCountdown {
    static func start(_ record: SessionRecord, locked: Bool) {
        endAll(except: nil)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = SessionActivityAttributes(sessionID: record.id.uuidString, startedAt: record.timing.startedAt)
        let state = SessionActivityAttributes.ContentState(endsAt: record.timing.endsAt, locked: locked)
        // staleDate: once the time is up the card switches to "done" even if the app is closed.
        _ = try? Activity.request(attributes: attributes,
                                  content: .init(state: state, staleDate: record.timing.endsAt),
                                  pushType: nil)
    }

    static func end() { endAll(except: nil) }

    /// Launch and foreground repair: no session means no countdown; a running session without
    /// one (for example after a phone restart) gets it back.
    static func reconcile(_ record: SessionRecord?, locked: Bool) {
        guard let record else { endAll(except: nil); return }
        let id = record.id.uuidString
        if Activity<SessionActivityAttributes>.activities.contains(where: { $0.attributes.sessionID == id }) {
            endAll(except: id)
        } else {
            start(record, locked: locked)
        }
    }

    private static func endAll(except keep: String?) {
        for activity in Activity<SessionActivityAttributes>.activities where activity.attributes.sessionID != keep {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
