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

    /// Returns nil unless the text is a well-formed Lock In offer.
    static func decode(_ text: String) -> PCPairingOffer? {
        guard let data = text.data(using: .utf8),
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

@MainActor
protocol PCTransport {
    func pair(offer: PCPairingOffer, deviceName: String) async throws -> PCLinkRecord
    func startSession(_ record: SessionRecord, link: PCLinkRecord) async throws
    func stopSession(id: UUID, link: PCLinkRecord) async throws
}
