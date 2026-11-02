import Foundation

/// Immutable timing for one focus session. The end timestamp is the single source of truth,
/// so every reader (clock, labels, completion) derives the same answer from `Date`
/// and nothing accumulates drift across backgrounding or relaunch.
struct SessionTiming: Equatable {
    let startedAt: Date
    let duration: TimeInterval

    var endsAt: Date { startedAt.addingTimeInterval(duration) }

    func remaining(at date: Date) -> TimeInterval {
        min(max(endsAt.timeIntervalSince(date), 0), duration)
    }

    func fractionRemaining(at date: Date) -> Double {
        duration > 0 ? remaining(at: date) / duration : 0
    }

    func isFinished(at date: Date) -> Bool {
        date >= endsAt
    }

    /// "MM:SS". Minutes are not wrapped, so 90 minutes reads "90:00".
    static func display(seconds: Int) -> String {
        let clamped = max(seconds, 0)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }
}
