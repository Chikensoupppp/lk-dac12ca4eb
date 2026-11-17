import Foundation
import Network

/// A Nogbox PC seen on the Wi-Fi. Its Bonjour TXT record carries the addresses, port and certificate
/// fingerprint, so the phone can talk to it safely before pairing (the same pinning as the QR code).
struct NearbyPC: Identifiable, Equatable {
    let name: String
    let hosts: [String]
    let port: Int
    let fp: String
    var id: String { fp }
}

/// "Find nearby PC": looks for `_nogbox._tcp` on the local network while the phone is not paired.
/// iOS asks for Local Network permission the first time this runs.
@MainActor
final class PCFinder: ObservableObject {
    @Published private(set) var found: [NearbyPC] = []
    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_nogbox._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let pcs = results.compactMap(Self.parse)
            Task { @MainActor in self?.found = pcs }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
        found = []
    }

    nonisolated private static func parse(_ result: NWBrowser.Result) -> NearbyPC? {
        guard case .bonjour(let txt) = result.metadata,
              let fp = txt.dictionary["fp"], fp.count == 64, fp.allSatisfy(\.isHexDigit),
              let hostText = txt.dictionary["hosts"] else { return nil }
        let hosts = hostText.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        guard !hosts.isEmpty else { return nil }
        let port = Int(txt.dictionary["port"] ?? "") ?? 47822
        var name = txt.dictionary["name"] ?? ""
        if name.isEmpty, case .service(let service, _, _, _) = result.endpoint { name = service }
        return NearbyPC(name: name.isEmpty ? "PC" : name, hosts: hosts, port: port, fp: fp)
    }
}
