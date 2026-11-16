import CloudKit
import SwiftUI

/// What a partner may see of someone in a lock-in. Sealed to each partner, so only they can read it.
/// The PC fills `app`, `appKey`, `title` and the pause fields only while the user's "Share with my
/// partner" switch on the PC is on.
struct PartnerStatus: Codable, Equatable {
    /// "locked", "break" or "free".
    var state: String
    var endsAt: Date?
    var duration: Double?
    var app: String?
    var appKey: String?
    var title: String?
    var pausedApp: String?
    var pausedSecondsLeft: Int?
    var sharing: Bool
    var sentAt: Date
}

/// The partner link through iCloud (CloudKit public database), like `RemoteKeys`: no Nogbox server.
/// - PartnerStatus: written by the person in a lock-in for each partner. Fields: ownerID, holderID,
///   payload (sealed PartnerStatus), signature, updatedAt.
/// - PartnerCommand: written by the partner to pause an app on the other person's PC. Fields:
///   commandID, ownerID, holderID, payload (sealed "appKey|seconds"), signature, createdAt.
/// Both record types must exist in the production schema (see HANDOFF).
enum PartnerCloud {
    private static var db: CKDatabase { CKContainer(identifier: RemoteKeys.containerID).publicCloudDatabase }
    private static let seenKey = "lockin.partner.commands.seen.v1"
    static let staleAfter: TimeInterval = 90

    nonisolated static func statusText(owner: String, holder: String, payload: String) -> String {
        "lockin.status|\(owner)|\(holder)|\(payload)"
    }

    nonisolated static func commandText(id: String, owner: String, holder: String, payload: String) -> String {
        "lockin.cmd|\(id)|\(owner)|\(holder)|\(payload)"
    }

    // MARK: Sending my status

    @MainActor
    static func publish(_ status: PartnerStatus, keys: KeyStore) async {
        guard !keys.holders.isEmpty, let json = try? JSONEncoder.partner.encode(status),
              let text = String(data: json, encoding: .utf8) else { return }
        for holder in keys.holders {
            guard let sealed = KeyStore.seal(text, to: holder) else { continue }
            let payload = sealed.base64EncodedString()
            let record = CKRecord(recordType: "PartnerStatus",
                                  recordID: CKRecord.ID(recordName: "ps-\(keys.myID)-\(holder.id)"))
            record["ownerID"] = keys.myID
            record["holderID"] = holder.id
            record["payload"] = payload
            record["signature"] = keys.sign(statusText(owner: keys.myID, holder: holder.id, payload: payload)).base64EncodedString()
            record["updatedAt"] = Date.now
            _ = try? await db.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        }
    }

    // MARK: Reading a friend's status

    @MainActor
    static func fetch(owner: KeyPerson, keys: KeyStore) async -> PartnerStatus? {
        let predicate = NSPredicate(format: "ownerID == %@ AND holderID == %@", owner.id, keys.myID)
        guard let (results, _) = try? await db.records(matching: CKQuery(recordType: "PartnerStatus", predicate: predicate), resultsLimit: 1),
              let record = try? results.first?.1.get(),
              let payload = record["payload"] as? String,
              let sig = (record["signature"] as? String).flatMap({ Data(base64Encoded: $0) }),
              KeyStore.verify(sig, of: statusText(owner: owner.id, holder: keys.myID, payload: payload), by: owner),
              let sealed = Data(base64Encoded: payload), let text = keys.open(sealed),
              let status = try? JSONDecoder.partner.decode(PartnerStatus.self, from: Data(text.utf8)) else { return nil }
        return status
    }

    // MARK: Pausing something on their PC

    @MainActor
    static func sendPause(to owner: KeyPerson, appKey: String, seconds: Int, keys: KeyStore) async -> Bool {
        let id = UUID().uuidString
        guard let sealed = KeyStore.seal("\(appKey)|\(seconds)", to: owner) else { return false }
        let payload = sealed.base64EncodedString()
        let record = CKRecord(recordType: "PartnerCommand", recordID: CKRecord.ID(recordName: "pc-\(id)"))
        record["commandID"] = id
        record["ownerID"] = owner.id
        record["holderID"] = keys.myID
        record["payload"] = payload
        record["signature"] = keys.sign(commandText(id: id, owner: owner.id, holder: keys.myID, payload: payload)).base64EncodedString()
        record["createdAt"] = Date.now
        return (try? await db.save(record)) != nil
    }

    /// Pause requests from my partners in the last two minutes that I have not handled yet. Each one is
    /// checked against its sender's signature and opened on this phone only.
    @MainActor
    static func pendingPauses(keys: KeyStore) async -> [(appKey: String, seconds: Int)] {
        guard !keys.holders.isEmpty else { return [] }
        let since = Date.now.addingTimeInterval(-120)
        let predicate = NSPredicate(format: "ownerID == %@ AND createdAt > %@", keys.myID, since as NSDate)
        guard let (results, _) = try? await db.records(matching: CKQuery(recordType: "PartnerCommand", predicate: predicate), resultsLimit: 10) else { return [] }
        var seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        var out: [(appKey: String, seconds: Int)] = []
        for (_, result) in results {
            guard let r = try? result.get(), let id = r["commandID"] as? String, !seen.contains(id),
                  let holderID = r["holderID"] as? String, let holder = keys.holders.first(where: { $0.id == holderID }),
                  let payload = r["payload"] as? String,
                  let sig = (r["signature"] as? String).flatMap({ Data(base64Encoded: $0) }),
                  KeyStore.verify(sig, of: commandText(id: id, owner: keys.myID, holder: holderID, payload: payload), by: holder),
                  let sealed = Data(base64Encoded: payload), let text = keys.open(sealed) else { continue }
            seen.insert(id)
            let parts = text.split(separator: "|", maxSplits: 1).map(String.init)
            if parts.count == 2, let seconds = Int(parts[1]) { out.append((appKey: parts[0], seconds: min(max(seconds, 60), 3600))) }
        }
        UserDefaults.standard.set(Array(seen.suffix(50)), forKey: seenKey)
        return out
    }
}

private extension JSONEncoder {
    static var partner: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; return e }
}
private extension JSONDecoder {
    static var partner: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970; return d }
}

// MARK: - The partner's screen

/// What the partner sees: a live clock, what is on the PC (only if the user allowed it), and a way
/// to pause that app or site for a few minutes.
struct PartnerWatchView: View {
    @ObservedObject var keys: KeyStore
    let person: KeyPerson
    let onDone: () -> Void

    @State private var status: PartnerStatus?
    @State private var loaded = false
    @State private var minutes = 15
    @State private var sending = false
    @State private var sent: String?

    private let top = Color(hex: 0xFFFAF1), bottom = Color(hex: 0xF8EAD5)
    private let ink = FocusPaper.ink, soft = FocusPaper.secondary
    private let card = Color(hex: 0xFFFCF6), border = Color(hex: 0xEAD9BF)

    var body: some View {
        ZStack {
            LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Done", action: onDone)
                            .font(.system(size: 17)).foregroundStyle(ink)
                            .padding(.horizontal, 20).frame(minHeight: 44)
                            .overlay(Capsule().stroke(border, lineWidth: 2))
                    }
                    header.padding(.top, 8)
                    TimelineView(.periodic(from: .now, by: 1)) { context in ring(now: context.date) }
                        .padding(.top, 16)
                    pcCard.padding(.top, 18)
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .preferredColorScheme(.light)
        .task {
            while !Task.isCancelled {
                status = await PartnerCloud.fetch(owner: person, keys: keys)
                loaded = true
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private var fresh: PartnerStatus? {
        guard let status, Date.now.timeIntervalSince(status.sentAt) < PartnerCloud.staleAfter else { return nil }
        return status
    }

    private var line: String {
        guard loaded else { return "Checking" }
        guard let s = fresh else { return status == nil ? "No news yet" : "Not in a lock-in" }
        switch s.state {
        case "locked": return "Locked in"
        case "break": return "On a break"
        default: return "Not in a lock-in"
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(String(person.name.prefix(1)).uppercased())
                .font(.system(size: 18, weight: .bold)).foregroundStyle(ink)
                .frame(width: 44, height: 44).background(Circle().fill(Color(hex: 0xF1E3CC)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.system(size: 24, weight: .bold)).foregroundStyle(ink)
                HStack(spacing: 8) {
                    Circle().fill(fresh?.state == "locked" ? FocusPaper.amber : Color(hex: 0xB9B09F)).frame(width: 9, height: 9)
                    Text(line).font(.system(size: 16)).foregroundStyle(soft)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func ring(now: Date) -> some View {
        let s = fresh
        let live = s?.state == "locked" || s?.state == "break"
        let left = live ? max(Int((s?.endsAt ?? now).timeIntervalSince(now)), 0) : 0
        let fraction = live && (s?.duration ?? 0) > 0 ? min(Double(left) / (s?.duration ?? 1), 1) : 0
        let total = Int(((s?.duration ?? 0) / 60).rounded())
        return ZStack {
            Circle().stroke(FocusPaper.line, lineWidth: 6)
            Circle().trim(from: 0, to: fraction)
                .stroke(FocusPaper.amber, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2), r = size.width / 2
                for i in 0..<60 {
                    let a = Double(i) * .pi / 30, big = i % 5 == 0
                    let r1 = r - (big ? 22 : 16), r2 = r - 10
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + sin(a) * r1, y: c.y - cos(a) * r1))
                    p.addLine(to: CGPoint(x: c.x + sin(a) * r2, y: c.y - cos(a) * r2))
                    ctx.stroke(p, with: .color(big ? FocusPaper.secondary : Color(hex: 0xB9B2A4)), lineWidth: big ? 1.6 : 1.1)
                }
            }
            VStack(spacing: 4) {
                Image("BrainExact").resizable().scaledToFit().frame(width: 104)
                    .opacity(live ? 1 : 0.85).accessibilityHidden(true)
                Text(live ? SessionTiming.display(seconds: left) : "Resting")
                    .font(.system(size: live ? 54 : 34, weight: .bold)).foregroundStyle(ink).monospacedDigit()
                if live && total > 0 {
                    Text("LEFT OF \(total)").font(.system(size: 13, weight: .semibold)).tracking(2).foregroundStyle(soft)
                }
            }
        }
        .frame(width: 280, height: 280)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(live ? "\(person.name) has \(SessionTiming.display(seconds: left)) left" : "\(person.name) is not in a lock-in")
    }

    @ViewBuilder private var pcCard: some View {
        if let s = fresh, s.state != "free" {
            VStack(alignment: .leading, spacing: 10) {
                Text("ON THEIR PC").font(.system(size: 12, weight: .semibold)).tracking(2.6).foregroundStyle(FocusPaper.amber)
                if !s.sharing {
                    Text("\(person.name) has not turned on sharing on their PC.")
                        .font(.system(size: 17)).foregroundStyle(soft)
                } else if let app = s.app, !app.isEmpty {
                    Text(s.title ?? app).font(.system(size: 20, weight: .semibold)).foregroundStyle(ink)
                    Text(s.title == nil ? "Window title hidden" : app).font(.system(size: 15)).foregroundStyle(soft)
                    pauseControls(s)
                } else {
                    Text("Nothing open right now.").font(.system(size: 17)).foregroundStyle(soft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22).fill(card))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(border, lineWidth: 1.5))
        } else if loaded {
            Text(status == nil ? "\(person.name)'s phone sends an update while they are locked in." : "You will see them here when they lock in.")
                .font(.system(size: 16)).foregroundStyle(soft)
        }
    }

    @ViewBuilder private func pauseControls(_ s: PartnerStatus) -> some View {
        if let paused = s.pausedApp, let left = s.pausedSecondsLeft, left > 0 {
            Text("\(paused) is paused for \(left / 60):\(String(format: "%02d", left % 60))")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(FocusPaper.amber).padding(.top, 6)
        } else if let key = s.appKey, s.state == "locked" {
            HStack(spacing: 8) {
                ForEach([5, 15, 60], id: \.self) { m in
                    Button { minutes = m } label: {
                        Text(m == 60 ? "1 hour" : "\(m) min").font(.system(size: 15, weight: .medium))
                            .foregroundStyle(minutes == m ? Color(hex: 0xFFFAF1) : soft)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 14).fill(minutes == m ? Color(hex: 0x3D2B1A) : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(minutes == m ? Color.clear : border, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
            Button {
                sending = true
                Task {
                    let ok = await PartnerCloud.sendPause(to: person, appKey: key, seconds: minutes * 60, keys: keys)
                    sent = ok ? "Sent. It can take a few seconds." : "Could not send. Check iCloud."
                    sending = false
                }
            } label: {
                Text("PAUSE \((s.app ?? "THIS").uppercased())").font(.system(size: 15, weight: .medium)).tracking(2.4)
                    .foregroundStyle(Color(hex: 0xFFFAF1))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(Color(hex: 0x3D2B1A)))
            }
            .buttonStyle(.plain).disabled(sending).opacity(sending ? 0.6 : 1)
            .accessibilityIdentifier("partner-pause")
            if let sent { Text(sent).font(.system(size: 14)).foregroundStyle(soft) }
        }
    }
}
