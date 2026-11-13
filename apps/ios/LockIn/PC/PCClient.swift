import CryptoKit
import Foundation
import Security

/// The exact session-start contract shared with the PC companion.
struct PCStartRequest: Encodable {
    let id: String
    let durationSeconds: Int
    let startedAt: String
    let task: String?
    let buddy: Bool
    let allow: [String]
    let guardianSeconds: Int?

    init(record: SessionRecord, extras: PCSessionExtras) {
        id = record.id.uuidString
        durationSeconds = Int(record.duration.rounded())
        startedAt = ISO8601DateFormatter().string(from: record.startedAt)
        task = extras.task
        buddy = extras.buddy
        allow = extras.allow
        guardianSeconds = extras.remindAfterMinutes.map { $0 * 60 }
    }
}

/// Talks to the Lock In companion on the PC over HTTPS. The PC's certificate is self-made,
/// so normal trust checks would fail. Instead the connection is accepted only when the
/// certificate's SHA-256 matches the fingerprint from the QR code.
@MainActor
final class PCClient: PCTransport {
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 4) {
        self.timeout = timeout
    }

    func pair(offer: PCPairingOffer, deviceName: String) async throws -> PCLinkRecord {
        struct Body: Encodable { let code: String; let deviceName: String }
        struct Reply: Decodable { let deviceId: String; let token: String }
        let (data, status) = try await send(
            hosts: offer.hosts, port: offer.port, fingerprint: offer.fp,
            path: "/pair", token: nil, body: Body(code: offer.code, deviceName: deviceName))
        guard status == 200 else { throw PCError.rejected(status) }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { throw PCError.badResponse }
        return PCLinkRecord(hosts: offer.hosts, port: offer.port, fingerprint: offer.fp,
                            token: reply.token, deviceId: reply.deviceId)
    }

    func startSession(_ record: SessionRecord, link: PCLinkRecord) async throws {
        try await startSession(record, extras: .none, link: link)
    }

    func startSession(_ record: SessionRecord, extras: PCSessionExtras, link: PCLinkRecord) async throws {
        let body = PCStartRequest(record: record, extras: extras)
        let (_, status) = try await send(
            hosts: link.hosts, port: link.port, fingerprint: link.fingerprint,
            path: "/session/start", token: link.token, body: body)
        guard status == 200 else { throw PCError.rejected(status) }
    }

    func sessionStatus(id: UUID, link: PCLinkRecord) async throws -> PCActivity? {
        struct Body: Encodable { let id: String }
        let (data, status) = try await send(
            hosts: link.hosts, port: link.port, fingerprint: link.fingerprint,
            path: "/session/status", token: link.token, body: Body(id: id.uuidString))
        guard status == 200 else { throw PCError.rejected(status) }
        return try? JSONDecoder().decode(PCActivity.self, from: data)
    }

    func stopSession(id: UUID, link: PCLinkRecord) async throws {
        struct Body: Encodable { let id: String }
        let (_, status) = try await send(
            hosts: link.hosts, port: link.port, fingerprint: link.fingerprint,
            path: "/session/stop", token: link.token, body: Body(id: id.uuidString))
        guard status == 200 else { throw PCError.rejected(status) }
    }

    /// Tries each address in order and returns the first answer. An HTTP error status is an answer.
    private func send<Body: Encodable>(
        hosts: [String], port: Int, fingerprint: String, path: String, token: String?, body: Body
    ) async throws -> (Data, Int) {
        let payload = try JSONEncoder().encode(body)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config, delegate: PinningDelegate(fingerprint: fingerprint), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        for host in hosts {
            try Task.checkCancellation()
            guard let url = URL(string: "https://\(host):\(port)\(path)") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = payload
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                return (data, http.statusCode)
            } catch {
                continue // this address did not answer; try the next one
            }
        }
        throw PCError.unreachable
    }
}

/// Accepts a TLS connection only if the server certificate matches the pinned fingerprint.
final class PinningDelegate: NSObject, URLSessionDelegate {
    private let expected: String

    init(fingerprint: String) {
        expected = fingerprint.uppercased()
    }

    static func fingerprint(of der: Data) -> String {
        SHA256.hash(data: der).map { String(format: "%02X", $0) }.joined()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first,
              Self.fingerprint(of: SecCertificateCopyData(leaf) as Data) == expected
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
