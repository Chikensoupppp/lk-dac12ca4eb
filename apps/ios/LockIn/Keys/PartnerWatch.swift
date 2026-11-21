import CloudKit
import UIKit
import SwiftUI
import UserNotifications

/// What a partner may see of someone in a lock-in. Sealed to each partner, so only they can read it.
/// The PC fills `app`, `appKey`, `title` and the pause fields. Sharing on the PC is always on; if no
/// PC is paired, `sharing` is false and those fields stay empty.
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
    /// This week so far, from SwipeLater's own sessions (never Screen Time numbers, which Apple keeps
    /// on the phone). Optional so older updates still read.
    var week: PartnerWeek? = nil
}

/// The weekly card a partner sees: minutes focused this week, the weekly goal and the streak.
struct PartnerWeek: Codable, Equatable {
    var minutes: Int
    var goalMinutes: Int?
    var streak: Int
}

/// A partner's note as the banner shows it: who it's from, and the line.
struct PartnerBanner: Equatable {
    let title: String
    let body: String
}

/// A short message from a partner (Brandon, 2026-11-20): a cheer during a lock-in, or a nudge to
/// start one. Sent as a PartnerCommand (sealed "note|cheer" / "note|nudge"), so no new record type.
enum PartnerNote: String {
    case cheer, nudge

    /// The line under the sender's name in the banner.
    var text: String {
        switch self {
        case .cheer: return "Keep going, you\u{2019}ve got this."
        case .nudge: return "Time to lock in?"
        }
    }

    /// Fewest seconds between two of these to the same person, so nobody gets spammed.
    var spacing: TimeInterval { self == .cheer ? 5 * 60 : 30 * 60 }
}

/// The partner link through iCloud (CloudKit public database), like `RemoteKeys`: no Nogbox server.
/// - PartnerStatus: written by the person in a lock-in for each partner. Fields: ownerID, holderID,
///   payload (sealed PartnerStatus), signature, updatedAt.
/// - PartnerCommand: written by the partner to pause an app on the other person's PC. Fields:
///   commandID, ownerID, holderID, payload (sealed "appKey|seconds", or "note|cheer" / "note|nudge"),
///   signature, createdAt.
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
        await sendCommand("\(appKey)|\(seconds)", to: owner, keys: keys)
    }

    /// A cheer or a nudge to the person I hold the key for.
    @MainActor
    static func sendNote(_ note: PartnerNote, to owner: KeyPerson, keys: KeyStore) async -> Bool {
        await sendCommand("note|\(note.rawValue)", to: owner, keys: keys)
    }

    @MainActor
    private static func sendCommand(_ text: String, to owner: KeyPerson, keys: KeyStore) async -> Bool {
        let id = UUID().uuidString
        guard let sealed = KeyStore.seal(text, to: owner) else { return false }
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

    /// What my partners sent that I have not handled yet: pauses from the last two minutes (older ones
    /// are dropped), and cheers and nudges from the last 12 hours. Each one is checked against its
    /// sender's signature and opened on this phone only.
    @MainActor
    static func pending(keys: KeyStore) async -> (pauses: [(appKey: String, seconds: Int)], notes: [(from: String, note: PartnerNote)]) {
        guard !keys.holders.isEmpty else { return ([], []) }
        let since = Date.now.addingTimeInterval(-12 * 3600)
        let predicate = NSPredicate(format: "ownerID == %@ AND createdAt > %@", keys.myID, since as NSDate)
        guard let (results, _) = try? await db.records(matching: CKQuery(recordType: "PartnerCommand", predicate: predicate), resultsLimit: 20) else { return ([], []) }
        var seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        var pauses: [(appKey: String, seconds: Int)] = []
        var notes: [(from: String, note: PartnerNote)] = []
        for (_, result) in results {
            guard let r = try? result.get(), let id = r["commandID"] as? String, !seen.contains(id),
                  let holderID = r["holderID"] as? String, let holder = keys.holders.first(where: { $0.id == holderID }),
                  let payload = r["payload"] as? String,
                  let sig = (r["signature"] as? String).flatMap({ Data(base64Encoded: $0) }),
                  KeyStore.verify(sig, of: commandText(id: id, owner: keys.myID, holder: holderID, payload: payload), by: holder),
                  let sealed = Data(base64Encoded: payload), let text = keys.open(sealed) else { continue }
            seen.insert(id)
            let parts = text.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0] == "note" {
                if let note = PartnerNote(rawValue: parts[1]) { notes.append((from: holder.name, note: note)) }
            } else if let seconds = Int(parts[1]),
                      let created = r["createdAt"] as? Date, Date.now.timeIntervalSince(created) < 120 {
                pauses.append((appKey: parts[0], seconds: min(max(seconds, 60), 3600)))
            }
        }
        UserDefaults.standard.set(Array(seen.suffix(50)), forKey: seenKey)
        return (pauses, notes)
    }

    /// Lets iCloud push "your partner checked in" to this phone when a partner sends a cheer, a nudge
    /// or a pause. The push can't say which (the message is sealed); the app shows it when opened.
    @MainActor
    static func subscribeToNotes(keys: KeyStore) async {
        guard !keys.holders.isEmpty else { return }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
        let id = "lockin.notes.\(keys.myID)"
        if (try? await db.subscription(for: id)) != nil { return }
        let sub = CKQuerySubscription(recordType: "PartnerCommand", predicate: NSPredicate(format: "ownerID == %@", keys.myID),
                                      subscriptionID: id, options: [.firesOnRecordCreation])
        let info = CKSubscription.NotificationInfo()
        info.title = "Your partner checked in"
        info.alertBody = "Open SwipeLater to see it."
        info.soundName = "default"
        sub.notificationInfo = info
        _ = try? await db.save(sub)
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
    @State private var noteSent: String?
    @State private var sendingNote = false

    // Apple-style (2026-11-21): the app's paper as a grouped background, white cards, a blue tint.
    private let ground = Ink.paper
    private let ink = Ink.ink, soft = Ink.ink.opacity(0.55)
    private let card = Color.white, hairline = Ink.ink.opacity(0.14)
    private let tint = Ink.blue

    var body: some View {
        ZStack {
            ground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Done", action: onDone)
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    header.padding(.top, 8)
                    TimelineView(.periodic(from: .now, by: 1)) { context in ring(now: context.date) }
                        .padding(.top, 16)
                    noteButton.padding(.top, 18)
                    weekCard.padding(.top, 18)
                    pcCard.padding(.top, 18)
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
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
                .frame(width: 44, height: 44).background(Circle().fill(ink.opacity(0.08)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.system(size: 28, weight: .bold)).tracking(-0.3).foregroundStyle(ink)
                HStack(spacing: 8) {
                    Circle().fill(fresh?.state == "locked" ? tint : ink.opacity(0.25)).frame(width: 9, height: 9)
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
            Circle().stroke(ink.opacity(0.1), lineWidth: 8)
            Circle().trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2), r = size.width / 2
                for i in 0..<60 {
                    let a = Double(i) * .pi / 30, big = i % 5 == 0
                    let r1 = r - (big ? 22 : 16), r2 = r - 10
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + sin(a) * r1, y: c.y - cos(a) * r1))
                    p.addLine(to: CGPoint(x: c.x + sin(a) * r2, y: c.y - cos(a) * r2))
                    ctx.stroke(p, with: .color(Ink.ink.opacity(big ? 0.45 : 0.2)), lineWidth: big ? 1.6 : 1.1)
                }
            }
            VStack(spacing: 4) {
                Image("BrainExact").resizable().scaledToFit().frame(width: 104)
                    .opacity(live ? 1 : 0.85).accessibilityHidden(true)
                Text(live ? SessionTiming.display(seconds: left) : "Resting")
                    .font(.system(size: live ? 54 : 34, weight: .bold)).foregroundStyle(ink).monospacedDigit()
                if live && total > 0 {
                    Text("left of \(total) min").font(.system(size: 15)).foregroundStyle(soft)
                }
            }
        }
        .frame(width: 280, height: 280)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(live ? "\(person.name) has \(SessionTiming.display(seconds: left)) left" : "\(person.name) is not in a lock-in")
    }

    // MARK: Cheer, nudge, this week

    /// While they're locked in: a cheer. Otherwise: a nudge to start. One tap sends a fixed line (no
    /// free text), spaced out so nobody gets spammed (`PartnerNote.spacing`).
    @ViewBuilder private var noteButton: some View {
        if loaded {
            let note: PartnerNote = fresh.map { $0.state != "free" } == true ? .cheer : .nudge
            let wait = noteWait(note)
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    sendingNote = true
                    Task {
                        let ok = await PartnerCloud.sendNote(note, to: person, keys: keys)
                        if ok { UserDefaults.standard.set(Date.now, forKey: noteKey(note)) }
                        noteSent = ok ? (note == .cheer ? "Cheer sent." : "Nudge sent.") : "Could not send. Check iCloud."
                        sendingNote = false
                    }
                } label: {
                    Label(note == .cheer ? "Send a cheer" : "Nudge \(person.name) to lock in",
                          systemImage: note == .cheer ? "hands.clap.fill" : "bell.badge.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ink))
                }
                .buttonStyle(.plain)
                .disabled(sendingNote || wait > 0)
                .opacity(sendingNote || wait > 0 ? 0.5 : 1)
                .accessibilityIdentifier(note == .cheer ? "partner-cheer" : "partner-nudge")
                if let noteSent {
                    Text(noteSent).font(.system(size: 13)).foregroundStyle(soft).padding(.horizontal, 4)
                } else if wait > 0 {
                    Text("You can send another in \(Int((wait / 60).rounded(.up))) min.")
                        .font(.system(size: 13)).foregroundStyle(soft).padding(.horizontal, 4)
                }
            }
        }
    }

    private func noteKey(_ note: PartnerNote) -> String { "lockin.partner.note.\(note.rawValue).\(person.id)" }

    /// Seconds until another note of this kind may go to this person.
    private func noteWait(_ note: PartnerNote) -> TimeInterval {
        guard let last = UserDefaults.standard.object(forKey: noteKey(note)) as? Date else { return 0 }
        return max(0, note.spacing - Date.now.timeIntervalSince(last))
    }

    /// Their week from their own sessions: minutes focused, the goal, the streak. Shown from the last
    /// update even when they're not locked in right now.
    @ViewBuilder private var weekCard: some View {
        if let week = status?.week {
            VStack(alignment: .leading, spacing: 10) {
                Text("THIS WEEK").font(.system(size: 13)).foregroundStyle(soft)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Self.hours(week.minutes)).font(.system(size: 34, weight: .bold)).tracking(-0.5).foregroundStyle(ink).monospacedDigit()
                    Text("focused").font(.system(size: 17)).foregroundStyle(soft)
                }
                if let goal = week.goalMinutes, goal > 0 {
                    ProgressView(value: min(Double(week.minutes) / Double(goal), 1))
                        .tint(tint)
                    Text(week.minutes >= goal ? "Weekly goal of \(Self.hours(goal)) met" : "Goal: \(Self.hours(goal))")
                        .font(.system(size: 15)).foregroundStyle(soft)
                }
                if week.streak > 0 {
                    Text("\(week.streak)-day streak").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(card))
            .accessibilityElement(children: .combine)
        }
    }

    /// "4h 50m", "45m".
    private static func hours(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    @ViewBuilder private var pcCard: some View {
        if let s = fresh, s.state != "free" {
            VStack(alignment: .leading, spacing: 10) {
                Text("ON THEIR PC").font(.system(size: 13)).foregroundStyle(soft)
                if !s.sharing {
                    Text("\(person.name) has no PC connected.")
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
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(card))
        } else if loaded {
            Text(status == nil ? "\(person.name)'s phone sends an update while they are locked in." : "You will see them here when they lock in.")
                .font(.system(size: 16)).foregroundStyle(soft)
        }
    }

    @ViewBuilder private func pauseControls(_ s: PartnerStatus) -> some View {
        if let paused = s.pausedApp, let left = s.pausedSecondsLeft, left > 0 {
            Text("\(paused) is paused for \(left / 60):\(String(format: "%02d", left % 60))")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(tint).padding(.top, 6)
        } else if let key = s.appKey, s.state == "locked" {
            HStack(spacing: 8) {
                ForEach([5, 15, 60], id: \.self) { m in
                    Button { minutes = m } label: {
                        Text(m == 60 ? "1 hour" : "\(m) min").font(.system(size: 15, weight: .medium))
                            .foregroundStyle(minutes == m ? Color.white : ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(minutes == m ? ink : ink.opacity(0.06)))
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
                Text("Pause \(s.app ?? "This")").font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ink))
            }
            .buttonStyle(.plain).disabled(sending).opacity(sending ? 0.6 : 1)
            .accessibilityIdentifier("partner-pause")
            if let sent { Text(sent).font(.system(size: 14)).foregroundStyle(soft) }
        }
    }
}
