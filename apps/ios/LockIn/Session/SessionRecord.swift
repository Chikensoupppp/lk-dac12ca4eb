import Foundation

/// The persisted form of an active focus session. Only absolute timestamps are stored,
/// so a relaunch derives the same answer as a continuous run (`SessionTiming` is rebuilt
/// from it and stays the single clock).
struct SessionRecord: Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let duration: TimeInterval

    init(id: UUID = UUID(), timing: SessionTiming) {
        self.id = id
        self.startedAt = timing.startedAt
        self.duration = timing.duration
    }

    var timing: SessionTiming { SessionTiming(startedAt: startedAt, duration: duration) }
}

/// What to do with a stored record when the app launches.
enum SessionRecovery: Equatable {
    case idle
    case active(SessionRecord)
    /// The end time passed while the app was not running. Complete exactly once, then clear.
    case expired(SessionRecord)

    /// Allowed slack when the device clock moved backwards after the session started.
    static let clockSkewTolerance: TimeInterval = 60

    static func resolve(_ record: SessionRecord?, now: Date) -> SessionRecovery {
        guard let record else { return .idle }
        let timing = record.timing
        // Reject records that cannot be real: no duration, or a start time so far in the
        // future that the clock must have been moved back. Never trap the user in a session.
        guard record.duration > 0,
              timing.endsAt.timeIntervalSince(now) <= record.duration + clockSkewTolerance
        else { return .idle }
        return timing.isFinished(at: now) ? .expired(record) : .active(record)
    }
}

protocol SessionStoring {
    func load() -> SessionRecord?
    func save(_ record: SessionRecord)
    func clear()
}

final class UserDefaultsSessionStore: SessionStoring {
    static let key = "lockin.activeSession.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> SessionRecord? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(SessionRecord.self, from: data)
    }

    func save(_ record: SessionRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() { defaults.removeObject(forKey: Self.key) }
}
