import Foundation
import MultipeerConnectivity
import NearbyInteraction

/// An unlock request. Signed by the person asking.
struct UnlockAsk: Codable, Equatable {
    let requestID: String
    let from: String
    let to: String
    let sessionID: String
    let nonce: String
    let reason: String
    let signature: Data
}

/// A Key Holder's answer. Signed by them; only fits the one request it answers.
struct UnlockAnswer: Codable, Equatable {
    let requestID: String
    let nonce: String
    let approved: Bool
    let signature: Data
}

private struct NearbyMessage: Codable {
    var card: KeyCard?
    var token: Data?
    var ask: UnlockAsk?
    var answer: UnlockAnswer?
}

/// Two phones in the same room. Multipeer Connectivity finds the other phone over Bluetooth and
/// peer-to-peer Wi-Fi only (no internet), and Nearby Interaction measures the distance between
/// phones that have the U1/U2 chip (iPhone 11 and newer). Nothing here can be relayed by text.
@MainActor
final class NearbyLink: NSObject, ObservableObject {
    /// Arm's reach, in meters, when both phones can measure distance.
    static let closeEnough: Float = 1.0
    private static let service = "lockin-key"

    @Published private(set) var peerCard: KeyCard?
    @Published private(set) var distance: Float?
    @Published private(set) var peerMeasures = false
    @Published private(set) var incomingAsk: UnlockAsk?
    @Published private(set) var answer: UnlockAnswer?

    private let myCard: KeyCard
    private let me: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var ni: NISession?

    init(card: KeyCard) {
        myCard = card
        me = MCPeerID(displayName: String(card.id.prefix(8)))
        super.init()
    }

    static var canMeasure: Bool { NISession.deviceCapabilities.supportsPreciseDistanceMeasurement }

    /// Close enough to count as "in person". Without distance chips, being connected over
    /// Bluetooth (about one room) is the check.
    var isClose: Bool {
        guard peerCard != nil else { return false }
        if Self.canMeasure && peerMeasures { return (distance ?? .infinity) <= Self.closeEnough }
        return true
    }

    func start() {
        stop()
        let s = MCSession(peer: me, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        session = s
        let adv = MCNearbyServiceAdvertiser(peer: me, discoveryInfo: ["id": myCard.id], serviceType: Self.service)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
        let br = MCNearbyServiceBrowser(peer: me, serviceType: Self.service)
        br.delegate = self
        br.startBrowsingForPeers()
        browser = br
        if Self.canMeasure {
            let n = NISession()
            n.delegate = self
            ni = n
        }
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        ni?.invalidate()
        advertiser = nil; browser = nil; session = nil; ni = nil
        peerCard = nil; distance = nil; peerMeasures = false
    }

    func send(ask: UnlockAsk) { send(NearbyMessage(ask: ask)) }
    func send(answer: UnlockAnswer) { send(NearbyMessage(answer: answer)) }
    func clearAsk() { incomingAsk = nil }

    private func send(_ message: NearbyMessage) {
        guard let session, !session.connectedPeers.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func connected() {
        var hello = NearbyMessage(card: myCard)
        if let token = ni?.discoveryToken {
            hello.token = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        }
        send(hello)
    }

    private func receive(_ data: Data) {
        guard let message = try? JSONDecoder().decode(NearbyMessage.self, from: data) else { return }
        if let card = message.card { peerCard = card }
        if let tokenData = message.token,
           let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: tokenData) {
            peerMeasures = true
            ni?.run(NINearbyPeerConfiguration(peerToken: token))
        }
        if let ask = message.ask { incomingAsk = ask }
        if let answer = message.answer { self.answer = answer }
    }
}

extension NearbyLink: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            if state == .connected { self.connected() }
            if state == .notConnected { self.peerCard = nil; self.distance = nil }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in self.receive(data) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension NearbyLink: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in invitationHandler(true, self.session) }
    }
}

extension NearbyLink: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            // Only one side invites, so the two phones do not invite each other at once.
            guard let session = self.session, let theirs = info?["id"], self.myCard.id < theirs else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 20)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension NearbyLink: NISessionDelegate {
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        let d = nearbyObjects.first?.distance
        Task { @MainActor in self.distance = d }
    }

    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in self.distance = nil }
    }
}
