import Foundation
import Security

protocol PCLinkStoring {
    func load() -> PCLinkRecord?
    func save(_ record: PCLinkRecord)
    func clear()
}

/// Keeps the pairing token in the Keychain, not in UserDefaults.
final class KeychainPCLinkStore: PCLinkStoring {
    private let service = "com.brandon132199.lockin.pc"
    private let account = "link"

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func load() -> PCLinkRecord? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(PCLinkRecord.self, from: data)
    }

    func save(_ record: PCLinkRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        clear()
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

/// Mirrors the phone's focus session to a paired PC. The phone stays the boss: it never waits
/// for the PC, and a PC that is off or unreachable never blocks or changes a session.
/// Starts retry until the PC answers or the session ends. Messages are sent one after another,
/// so a late start cannot arrive after the stop for the same session.
@MainActor
final class PCLink: ObservableObject {
    enum Status: Equatable {
        case notPaired
        /// Paired, but nothing has been sent yet in this run.
        case paired
        /// The last message got through.
        case connected
        /// Paired, but the PC did not answer. A running session keeps retrying.
        case offline
    }

    @Published private(set) var status: Status
    /// Plain-language reason for the last problem, or nil.
    @Published private(set) var problem: String?
    @Published private(set) var isPairing = false
    /// While a "Find nearby PC" ask waits for the owner's Allow: the code the PC shows too.
    @Published private(set) var nearbyCode: String?
    /// What the PC reports during a session (front app, nudges), or nil.
    @Published private(set) var activity: PCActivity?

    private let store: PCLinkStoring
    private let transport: PCTransport
    private let retryDelay: Duration
    private var link: PCLinkRecord?
    private var activeSession: UUID?
    private var chain: Task<Void, Never>?
    private var poll: Task<Void, Never>?
    private let pollDelay: Duration

    /// Pass nothing for the real Keychain and the real PC client. Tests pass fakes. The real
    /// ones are built inside, on the main actor, as `RestrictionController` does.
    init(
        store: PCLinkStoring? = nil,
        transport: PCTransport? = nil,
        retryDelay: Duration = .seconds(5),
        pollDelay: Duration = .seconds(15)
    ) {
        let store = store ?? KeychainPCLinkStore()
        self.store = store
        self.transport = transport ?? PCClient()
        self.retryDelay = retryDelay
        self.pollDelay = pollDelay
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-state") { store.clear() }
        #endif
        let saved = store.load()
        link = saved
        status = saved == nil ? .notPaired : .paired
    }

    var isPaired: Bool { link != nil }

    func report(_ message: String) {
        problem = message
    }

    func pair(offer: PCPairingOffer, deviceName: String = "iPhone") async {
        guard !isPairing else { return }
        isPairing = true
        problem = nil
        defer { isPairing = false }
        do {
            let record = try await transport.pair(offer: offer, deviceName: deviceName)
            store.save(record)
            link = record
            status = .paired
        } catch PCError.rejected(let code) {
            problem = code == 403
                ? "The QR code expired. Make a new one."
                : "The PC said no. Make a new QR code."
        } catch PCError.unreachable {
            problem = "Could not reach the PC."
        } catch {
            problem = "Pairing failed. Make a new QR code."
        }
    }

    /// "Find nearby PC": asks the PC to pair, shows a 4-digit code here (the PC shows the same one),
    /// waits up to a minute for the owner to click Allow, then pairs like the QR code does.
    func pairNearby(_ pc: NearbyPC, deviceName: String = "iPhone") async {
        guard !isPairing, nearbyCode == nil else { return }
        problem = nil
        let code = String(format: "%04d", Int.random(in: 0...9999))
        nearbyCode = code
        var offer: PCPairingOffer?
        do {
            let id = try await transport.askNearby(pc, device: deviceName, code: code)
            let deadline = Date.now.addingTimeInterval(65)
            waiting: while Date.now < deadline {
                try await Task.sleep(for: .milliseconds(1500))
                let answer = try await transport.nearbyStatus(pc, id: id)
                switch answer.state {
                case "allowed": offer = answer.offer; break waiting
                case "denied": problem = "The PC said no."; break waiting
                case "expired", "done": problem = "No answer on the PC. Try again."; break waiting
                default: continue
                }
            }
            if offer == nil && problem == nil { problem = "No answer on the PC. Try again." }
        } catch PCError.rejected(429) {
            problem = "The PC is already asking. Answer it there first."
        } catch PCError.unreachable {
            problem = "Could not reach the PC."
        } catch {
            problem = "Could not connect. Try again."
        }
        nearbyCode = nil
        if let offer { await pair(offer: offer, deviceName: deviceName) }
    }

    func forget() {
        stopPolling()
        store.clear()
        link = nil
        activeSession = nil
        status = .notPaired
        problem = nil
    }

    /// Call when a session starts, and again after a relaunch that restores a running session.
    func sessionStarted(_ record: SessionRecord, extras: PCSessionExtras = .none) {
        guard let link else { return }
        activeSession = record.id
        enqueue { [self] in await runStart(record, extras: extras, link: link) }
    }

    /// A partner paused an app or site on the PC. Does nothing without a paired PC and a running session.
    func partnerPause(appKey: String, seconds: Int) {
        guard let link, let id = activeSession else { return }
        enqueue { [self] in try? await transport.partnerPause(id: id, appKey: appKey, seconds: seconds, link: link) }
    }

    /// Sends the week summary for the PC window's "This week" row. Does nothing without a paired PC.
    func sendWeek(_ week: PCWeek) {
        guard let link else { return }
        enqueue { [self] in try? await transport.sendWeek(week, link: link) }
    }

    /// Call when a session ends early or finishes. Safe to call more than once.
    func sessionEnded(_ id: UUID) {
        guard let link else { return }
        if activeSession == id { activeSession = nil }
        stopPolling()
        enqueue { [self] in await runStop(id, link: link) }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = chain
        chain = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }

    private func runStart(_ record: SessionRecord, extras: PCSessionExtras, link: PCLinkRecord) async {
        while activeSession == record.id, !record.timing.isFinished(at: .now) {
            do {
                try await transport.startSession(record, extras: extras, link: link)
                status = .connected
                problem = nil
                startPolling(record, link: link)
                return
            } catch PCError.rejected(401) {
                forget()
                problem = "The PC forgot this phone."
                return
            } catch PCError.rejected(409) {
                status = .connected
                problem = "The PC is busy with another session."
                return
            } catch PCError.rejected {
                status = .connected
                problem = "The PC refused this session."
                return
            } catch {
                status = .offline
                try? await Task.sleep(for: retryDelay)
            }
        }
    }

    /// Asks the PC what it sees every so often during the session. A PC app too old to know
    /// `/session/status` answers 404, and polling stops quietly.
    private func startPolling(_ record: SessionRecord, link: PCLinkRecord) {
        poll?.cancel()
        poll = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.activeSession == record.id, !record.timing.isFinished(at: .now) {
                do {
                    self.activity = try await self.transport.sessionStatus(id: record.id, link: link)
                } catch PCError.rejected {
                    return
                } catch {
                    // Offline for a moment; keep the last answer and try again.
                }
                try? await Task.sleep(for: self.pollDelay)
            }
        }
    }

    #if DEBUG
    /// Screenshot runs only: show a PC report without a PC.
    func debugShow(_ sample: PCActivity) { activity = sample }
    #endif

    private func stopPolling() {
        poll?.cancel()
        poll = nil
        activity = nil
    }

    private func runStop(_ id: UUID, link: PCLinkRecord) async {
        for attempt in 0..<3 {
            do {
                try await transport.stopSession(id: id, link: link)
                status = .connected
                return
            } catch PCError.rejected {
                return // the PC answered; retrying will not change that
            } catch {
                status = .offline
                if attempt < 2 { try? await Task.sleep(for: retryDelay) }
            }
        }
        // The PC ends the session itself at the end time, so a missed stop is not fatal.
    }
}
