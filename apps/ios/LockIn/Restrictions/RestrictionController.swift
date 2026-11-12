import FamilyControls
import Foundation

/// Owns the restriction lifecycle for a focus session. It never decides whether a session
/// is running; callers pass the session in. Every path that ends a session calls `end()`,
/// which is idempotent, and launch/foreground call `reconcile` to repair stale state.
@MainActor
final class RestrictionController: ObservableObject {
    enum Status: Equatable {
        case needsAuthorization
        case denied
        case ready
        case active
        case skipped(RestrictionSkipReason)
        case failed(String)
    }

    struct AppliedMarker: Codable, Equatable {
        let sessionID: UUID
        let endsAt: Date
    }

    static let selectionKey = "lockin.restrictionSelection.v1"
    static let markerKey = "lockin.restrictionsApplied.v1"

    @Published private(set) var status: Status = .needsAuthorization
    @Published private(set) var selection: FamilyActivitySelection

    private let client: ScreenTimeClient
    private let defaults: UserDefaults
    private let selectionIsEmpty: (FamilyActivitySelection) -> Bool

    init(
        client: ScreenTimeClient? = nil,
        defaults: UserDefaults = .standard,
        selectionIsEmpty: @escaping (FamilyActivitySelection) -> Bool = RestrictionController.defaultIsEmpty
    ) {
        self.client = client ?? SystemScreenTimeClient()
        self.defaults = defaults
        self.selectionIsEmpty = selectionIsEmpty
        if let data = defaults.data(forKey: Self.selectionKey),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        } else {
            selection = FamilyActivitySelection()
        }
        refresh()
    }

    nonisolated static func defaultIsEmpty(_ selection: FamilyActivitySelection) -> Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }

    var hasSelection: Bool { !selectionIsEmpty(selection) }

    var appliedMarker: AppliedMarker? {
        defaults.data(forKey: Self.markerKey).flatMap { try? JSONDecoder().decode(AppliedMarker.self, from: $0) }
    }

    func setSelection(_ newValue: FamilyActivitySelection) {
        selection = newValue
        if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: Self.selectionKey) }
    }

    /// Re-read authorization. Safe to call on appear and whenever the app becomes active.
    func refresh() {
        guard status != .active else { return }
        switch client.authorization {
        case .notDetermined: status = .needsAuthorization
        case .denied: status = .denied
        case .approved: status = .ready
        }
    }

    func requestAuthorization() async {
        do {
            try await client.requestAuthorization()
            refresh()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Apply restrictions for a freshly started session. Fails closed: if the backup cleanup
    /// cannot be scheduled, no shield is applied, so no state exists that only this process
    /// could remove.
    func begin(_ record: SessionRecord, locked: Bool = false, now: Date = .now) {
        let plan = RestrictionPlanner.plan(
            for: record, now: now,
            isAuthorized: client.authorization == .approved,
            hasSelection: hasSelection
        )
        switch plan {
        case .skip(let reason):
            status = .skipped(reason)
        case .apply(let activity, let start, let end):
            do {
                try client.startMonitoring(activity: activity, from: start, to: end)
            } catch {
                client.stopMonitoring()
                status = .failed(error.localizedDescription)
                return
            }
            client.applyShield(selection)
            if locked { client.applyLock(true) }
            let marker = AppliedMarker(sessionID: record.id, endsAt: record.timing.endsAt)
            if let data = try? JSONEncoder().encode(marker) { defaults.set(data, forKey: Self.markerKey) }
            status = .active
        }
    }

    /// Remove everything Lock In applied. Called on early end, natural completion, revoked
    /// authorization, and stale-state repair. Idempotent.
    func end() {
        client.stopMonitoring()
        client.clearShield()
        defaults.removeObject(forKey: Self.markerKey)
        status = .needsAuthorization
        refresh()
    }

    /// Repair state at launch/foreground. `activeSessionID` is the session `FocusView.timing`
    /// currently describes, or nil when idle.
    func reconcile(activeSessionID: UUID?, now: Date = .now) {
        guard let activeSessionID else { end(); return }
        guard let marker = appliedMarker else { refresh(); return }
        let stale = marker.sessionID != activeSessionID || now >= marker.endsAt
        if stale || client.authorization != .approved {
            end()
        } else {
            status = .active
        }
    }

    var statusLine: String? {
        switch status {
        case .active: return "Screen Time shields on"
        case .failed: return "Shields not started"
        case .skipped(.tooShort): return "Shields need 15+ minutes"
        default: return nil
        }
    }
}
