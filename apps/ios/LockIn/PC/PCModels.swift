import Foundation

/// What the PC's QR code carries. The PC side is described in HANDOFF.md ("Windows pairing, PC side").
struct PCPairingOffer: Codable, Equatable {
    let v: Int
    let hosts: [String]
    let port: Int
    /// SHA-256 of the PC's certificate, hex. The phone trusts only this certificate.
    let fp: String
    /// One-time code, valid for a few minutes, for one phone.
    let code: String
    let expiresAt: String

    /// Returns nil unless the text is a well-formed Nogbox offer. Accepts the plain JSON and the
    /// `nogbox://pair?d=<base64url JSON>` link the PC's QR code carries (so the Camera app opens Nogbox).
    static func decode(_ text: String) -> PCPairingOffer? {
        var json = text
        if let url = URL(string: text), url.scheme == "nogbox", url.host == "pair",
           let d = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "d" })?.value {
            var b64 = d.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            while b64.count % 4 != 0 { b64 += "=" }
            guard let raw = Data(base64Encoded: b64), let decoded = String(data: raw, encoding: .utf8) else { return nil }
            json = decoded
        }
        guard let data = json.data(using: .utf8),
              let offer = try? JSONDecoder().decode(PCPairingOffer.self, from: data),
              offer.v == 1,
              !offer.hosts.isEmpty,
              offer.hosts.allSatisfy(Self.isIPv4),
              (1...65535).contains(offer.port),
              offer.fp.count == 64,
              offer.fp.allSatisfy(\.isHexDigit),
              !offer.code.isEmpty
        else { return nil }
        return offer
    }

    private static func isIPv4(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { part in
            guard let n = Int(part), (0...255).contains(n) else { return false }
            return part.allSatisfy(\.isNumber)
        }
    }
}

/// A paired PC. Kept in the Keychain.
struct PCLinkRecord: Codable, Equatable {
    var hosts: [String]
    var port: Int
    var fingerprint: String
    var token: String
    var deviceId: String
}

enum PCError: Error, Equatable {
    /// No address answered (off, other network, firewall, or Local Network access denied).
    case unreachable
    /// The PC answered with this HTTP status.
    case rejected(Int)
    case badResponse
}

/// Extra things the phone tells the PC when a session starts. Older PC apps ignore them.
struct PCSessionExtras: Equatable {
    /// What the user is working on ("Studying"). The PC opens the workspace saved under this name.
    var task: String?
    /// Show the desk buddy (the brain in the corner of the PC screen) during the session.
    var buddy: Bool
    /// Explicit app/site allowances for this session; no apps are allowed by default.
    var allow: [String] = []
    /// Minutes of steady Shorts or Reddit scrolling before the buddy gives a gentle reminder (nil: the PC's default).
    var remindAfterMinutes: Int? = nil
    /// A Locked session (Plus). The PC only acts on it after checking Plus with RevenueCat itself.
    var locked: Bool = false
    /// This phone's RevenueCat user id, so the PC can check Plus. Nil when RevenueCat is off.
    var rcUserId: String? = nil

    static let none = PCSessionExtras(task: nil, buddy: false)
}

/// What the PC sees during a session, for the line under the clock.
struct PCActivity: Codable, Equatable {
    /// The app in front on the PC, by its plain name ("Docs", "YouTube").
    let app: String?
    /// The front app belongs to the task's workspace (or is not on the distraction list).
    let onTask: Bool
    /// Times the buddy nudged the user back this session.
    let nudges: Int
    /// A buddy break taken on the PC: how long it is. The phone moves the session end later by this, once.
    var breakSeconds: Int? = nil
    /// Seconds left in that break, while it runs.
    var breakSecondsLeft: Int? = nil
    /// Partner sharing, set by the PC only while the user's switch there is on.
    var title: String? = nil
    var appKey: String? = nil
    var pausedApp: String? = nil
    var pausedSecondsLeft: Int? = nil
    var sharing: Bool? = nil
}

@MainActor
protocol PCTransport {
    func pair(offer: PCPairingOffer, deviceName: String) async throws -> PCLinkRecord
    func startSession(_ record: SessionRecord, link: PCLinkRecord) async throws
    func startSession(_ record: SessionRecord, extras: PCSessionExtras, link: PCLinkRecord) async throws
    func stopSession(id: UUID, link: PCLinkRecord) async throws
    /// Nil when the PC has nothing to report yet.
    func sessionStatus(id: UUID, link: PCLinkRecord) async throws -> PCActivity?
    /// The partner paused an app or site on this PC.
    func partnerPause(id: UUID, appKey: String, seconds: Int, link: PCLinkRecord) async throws
}

extension PCTransport {
    func startSession(_ record: SessionRecord, extras: PCSessionExtras, link: PCLinkRecord) async throws {
        try await startSession(record, link: link)
    }

    func sessionStatus(id: UUID, link: PCLinkRecord) async throws -> PCActivity? { nil }
    func partnerPause(id: UUID, appKey: String, seconds: Int, link: PCLinkRecord) async throws {}
}
