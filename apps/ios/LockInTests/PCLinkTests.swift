import XCTest
@testable import LockIn

private final class MemoryStore: PCLinkStoring {
    var record: PCLinkRecord?
    func load() -> PCLinkRecord? { record }
    func save(_ record: PCLinkRecord) { self.record = record }
    func clear() { record = nil }
}

@MainActor
private final class FakeTransport: PCTransport {
    var pairResult: Result<PCLinkRecord, Error> = .failure(PCError.unreachable)
    /// Consumed one per start attempt; when empty, starts succeed.
    var startFailures: [Error] = []
    private(set) var startAttempts = 0
    private(set) var started: [UUID] = []
    private(set) var stopped: [UUID] = []

    func pair(offer: PCPairingOffer, deviceName: String) async throws -> PCLinkRecord {
        try pairResult.get()
    }

    func startSession(_ record: SessionRecord, link: PCLinkRecord) async throws {
        startAttempts += 1
        if !startFailures.isEmpty { throw startFailures.removeFirst() }
        started.append(record.id)
    }

    func stopSession(id: UUID, link: PCLinkRecord) async throws {
        stopped.append(id)
    }
}

@MainActor
final class PCLinkTests: XCTestCase {
    private let sample = PCLinkRecord(
        hosts: ["192.168.1.5"], port: 47822,
        fingerprint: String(repeating: "A", count: 64), token: "token", deviceId: "device")

    func testSessionStartPayloadContainsBuddySettings() throws {
        let record = session()
        let extras = PCSessionExtras(task: "Studying", buddy: true, allow: ["youtube"], remindAfterMinutes: 5)
        let data = try JSONEncoder().encode(PCStartRequest(record: record, extras: extras))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["id"] as? String, record.id.uuidString)
        XCTAssertEqual(json["task"] as? String, "Studying")
        XCTAssertEqual(json["buddy"] as? Bool, true)
        XCTAssertEqual(json["allow"] as? [String], ["youtube"])
        XCTAssertEqual(json["guardianSeconds"] as? Int, 300)
    }

    private func session(minutes: Double = 15) -> SessionRecord {
        SessionRecord(timing: SessionTiming(startedAt: .now, duration: minutes * 60))
    }

    private func makeLink(paired: Bool, transport: FakeTransport, store: MemoryStore = MemoryStore()) -> PCLink {
        if paired { store.record = sample }
        return PCLink(store: store, transport: transport, retryDelay: .milliseconds(5))
    }

    /// Polls until the condition holds. Fails the test if it never does.
    private func waitUntil(_ description: String, timeout: TimeInterval = 3, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return XCTFail("Timed out waiting for: \(description)") }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testUnpairedPhoneNeverTouchesTheNetwork() async {
        let transport = FakeTransport()
        let link = makeLink(paired: false, transport: transport)
        XCTAssertEqual(link.status, .notPaired)
        let record = session()
        link.sessionStarted(record)
        link.sessionEnded(record.id)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(transport.startAttempts, 0)
        XCTAssertTrue(transport.stopped.isEmpty)
    }

    func testPairedStartReachesThePcAndShowsConnected() async {
        let transport = FakeTransport()
        let link = makeLink(paired: true, transport: transport)
        XCTAssertEqual(link.status, .paired)
        let record = session()
        link.sessionStarted(record)
        await waitUntil("start sent") { transport.started == [record.id] }
        XCTAssertEqual(link.status, .connected)
        XCTAssertNil(link.problem)
    }

    func testRetriesUntilThePcAnswers() async {
        let transport = FakeTransport()
        transport.startFailures = [PCError.unreachable, PCError.unreachable]
        let link = makeLink(paired: true, transport: transport)
        let record = session()
        link.sessionStarted(record)
        await waitUntil("third try succeeds") { transport.started == [record.id] }
        XCTAssertEqual(transport.startAttempts, 3)
        XCTAssertEqual(link.status, .connected)
    }

    func testOfflinePcDoesNotChangeThePhoneSessionAndShowsOffline() async {
        let transport = FakeTransport()
        transport.startFailures = Array(repeating: PCError.unreachable, count: 1000)
        let link = makeLink(paired: true, transport: transport)
        link.sessionStarted(session())
        await waitUntil("offline shown") { link.status == .offline }
    }

    func testEndingStopsTheRetriesAndSendsStop() async {
        let transport = FakeTransport()
        transport.startFailures = Array(repeating: PCError.unreachable, count: 1000)
        let link = makeLink(paired: true, transport: transport)
        let record = session()
        link.sessionStarted(record)
        await waitUntil("retrying") { transport.startAttempts >= 2 }
        link.sessionEnded(record.id)
        await waitUntil("stop sent") { transport.stopped == [record.id] }
        let attempts = transport.startAttempts
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(transport.startAttempts, attempts, "no more start retries after the session ended")
    }

    func testRejectedTokenForgetsThePcAndExplains() async {
        let transport = FakeTransport()
        transport.startFailures = [PCError.rejected(401)]
        let store = MemoryStore()
        let link = makeLink(paired: true, transport: transport, store: store)
        link.sessionStarted(session())
        await waitUntil("unpaired") { link.status == .notPaired }
        XCTAssertNil(store.record)
        XCTAssertNotNil(link.problem)
        XCTAssertEqual(transport.startAttempts, 1)
    }

    func testBusyPcIsReportedAndNotRetried() async {
        let transport = FakeTransport()
        transport.startFailures = [PCError.rejected(409)]
        let link = makeLink(paired: true, transport: transport)
        link.sessionStarted(session())
        await waitUntil("problem shown") { link.problem != nil }
        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(transport.startAttempts, 1)
        XCTAssertEqual(link.status, .connected)
    }

    func testPairingSavesTheLinkAndFailureExplains() async {
        let transport = FakeTransport()
        transport.pairResult = .success(sample)
        let store = MemoryStore()
        let link = makeLink(paired: false, transport: transport, store: store)
        let offer = PCPairingOffer(v: 1, hosts: ["192.168.1.5"], port: 47822, fp: sample.fingerprint, code: "c", expiresAt: "x")
        await link.pair(offer: offer)
        XCTAssertEqual(link.status, .paired)
        XCTAssertEqual(store.record, sample)

        let failing = FakeTransport()
        failing.pairResult = .failure(PCError.rejected(403))
        let other = makeLink(paired: false, transport: failing)
        await other.pair(offer: offer)
        XCTAssertEqual(other.status, .notPaired)
        XCTAssertNotNil(other.problem)
    }

    func testForgetClearsEverything() {
        let store = MemoryStore()
        let link = makeLink(paired: true, transport: FakeTransport(), store: store)
        link.forget()
        XCTAssertEqual(link.status, .notPaired)
        XCTAssertNil(store.record)
    }
}

final class PCModelsTests: XCTestCase {
    private let validJSON = """
    {"v":1,"hosts":["172.20.10.2","192.168.4.21"],"port":47822,\
    "fp":"\(String(repeating: "AB", count: 32))","code":"abc_DEF-123","expiresAt":"2026-11-04T05:03:28.1234567+00:00"}
    """

    func testDecodesTheOfferTheWindowsAppMakes() {
        let offer = PCPairingOffer.decode(validJSON)
        XCTAssertEqual(offer?.hosts, ["172.20.10.2", "192.168.4.21"])
        XCTAssertEqual(offer?.port, 47822)
        XCTAssertEqual(offer?.code, "abc_DEF-123")
    }

    func testRejectsAnythingThatIsNotALockInOffer() {
        XCTAssertNil(PCPairingOffer.decode("https://example.com"))
        XCTAssertNil(PCPairingOffer.decode("{}"))
        XCTAssertNil(PCPairingOffer.decode(validJSON.replacingOccurrences(of: "\"v\":1", with: "\"v\":2")))
        XCTAssertNil(PCPairingOffer.decode(validJSON.replacingOccurrences(of: "172.20.10.2", with: "evil.example.com")))
        XCTAssertNil(PCPairingOffer.decode(validJSON.replacingOccurrences(of: "47822", with: "0")))
        XCTAssertNil(PCPairingOffer.decode(validJSON.replacingOccurrences(of: String(repeating: "AB", count: 32), with: "short")))
    }

    func testFingerprintIsUppercaseSha256() {
        XCTAssertEqual(
            PinningDelegate.fingerprint(of: Data("abc".utf8)),
            "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD")
    }
}
