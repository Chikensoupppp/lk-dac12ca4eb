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

    private let store: PCLinkStoring
    private let transport: PCTransport
    private let retryDelay: Duration
    private var link: PCLinkRecord?
    private var activeSession: UUID?
    private var chain: Task<Void, Never>?

    /// Pass nothing for the real Keychain and the real PC client. Tests pass fakes. The real
    /// ones are built inside, on the main actor, as `RestrictionController` does.
    init(
        store: PCLinkStoring? = nil,
        transport: PCTransport? = nil,
        retryDelay: Duration = .seconds(5)
    ) {
        let store = store ?? KeychainPCLinkStore()
        self.store = store
        self.transport = transport ?? PCClient()
        self.retryDelay = retryDelay
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

    func forget() {
        store.clear()
        link = nil
        activeSession = nil
        status = .notPaired
        problem = nil
    }

    /// Call when a session starts, and again after a relaunch that restores a running session.
    func sessionStarted(_ record: SessionRecord) {
        guard let link else { return }
        activeSession = record.id
        enqueue { [self] in await runStart(record, link: link) }
    }

    /// Call when a session ends early or finishes. Safe to call more than once.
    func sessionEnded(_ id: UUID) {
        guard let link else { return }
        if activeSession == id { activeSession = nil }
        enqueue { [self] in await runStop(id, link: link) }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = chain
        chain = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }

    private func runStart(_ record: SessionRecord, link: PCLinkRecord) async {
        while activeSession == record.id, !record.timing.isFinished(at: .now) {
            do {
                try await transport.startSession(record, link: link)
                status = .connected
                problem = nil
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
