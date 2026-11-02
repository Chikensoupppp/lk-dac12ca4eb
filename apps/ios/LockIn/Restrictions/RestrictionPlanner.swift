import Foundation

enum RestrictionSkipReason: Equatable {
    case notAuthorized
    case noSelection
    /// Shorter than Apple's 15 minute minimum interval, so no OS-side backup cleanup exists.
    /// Shields are never applied without a backup removal path.
    case tooShort
    case alreadyExpired
}

enum RestrictionPlan: Equatable {
    case skip(RestrictionSkipReason)
    case apply(activity: String, intervalStart: Date, intervalEnd: Date)
}

enum RestrictionPlanner {
    static func plan(for record: SessionRecord, now: Date, isAuthorized: Bool, hasSelection: Bool) -> RestrictionPlan {
        guard isAuthorized else { return .skip(.notAuthorized) }
        guard hasSelection else { return .skip(.noSelection) }
        let timing = record.timing
        guard !timing.isFinished(at: now) else { return .skip(.alreadyExpired) }
        guard record.duration >= RestrictionNaming.minimumMonitoringInterval else { return .skip(.tooShort) }
        let start = Date(timeIntervalSince1970: record.startedAt.timeIntervalSince1970.rounded(.down))
        let end = Date(timeIntervalSince1970:
            (timing.endsAt.timeIntervalSince1970 + RestrictionNaming.cleanupBuffer).rounded(.up))
        return .apply(
            activity: RestrictionNaming.activityName(sessionID: record.id, endsAt: timing.endsAt),
            intervalStart: start,
            intervalEnd: end
        )
    }
}
