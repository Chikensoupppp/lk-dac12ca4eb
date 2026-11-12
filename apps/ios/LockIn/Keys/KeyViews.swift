import SwiftUI

private enum KInk {
    static let bg = BrainDrawing.bg
    static let panel = BrainDrawing.panel
    static let cream = BrainDrawing.cream
    static let green = BrainDrawing.green
    static let alarm = BrainDrawing.alarm
}

private struct KTitle: View {
    let text: String
    var body: some View {
        Text(text).font(PrintFont.head(48)).foregroundStyle(KInk.cream).fixedSize(horizontal: false, vertical: true)
    }
}

private struct KBody: View {
    let text: String
    var body: some View {
        Text(text).font(PrintFont.body(16)).foregroundStyle(KInk.cream.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
private func newAsk(keys: KeyStore, holder: KeyPerson, sessionID: UUID, reason: String) -> UnlockAsk {
    let requestID = UUID().uuidString
    let nonce = KeyStore.newNonce()
    let text = KeyStore.requestText(requestID: requestID, from: keys.myID, to: holder.id, sessionID: sessionID.uuidString, nonce: nonce)
    return UnlockAsk(requestID: requestID, from: keys.myID, to: holder.id, sessionID: sessionID.uuidString,
                     nonce: nonce, reason: reason, signature: keys.sign(text))
}

/// True only for a real "yes" from this Key Holder to exactly this request.
private func approved(_ answer: UnlockAnswer, for ask: UnlockAsk, by holder: KeyPerson) -> Bool {
    answer.requestID == ask.requestID && answer.nonce == ask.nonce && answer.approved &&
        KeyStore.verify(answer.signature, of: KeyStore.answerText(requestID: ask.requestID, nonce: ask.nonce, approved: true), by: holder)
}

// MARK: - Keys sheet (from the main screen)

/// Pair with friends in person, see who holds your key, and let a friend out.
struct KeysSheet: View {
    @ObservedObject var keys: KeyStore
    let done: () -> Void
    @State private var pairing = false
    @State private var helping = false
    @State private var pending: [RemoteKeys.Pending] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    KTitle(text: "Keys.")
                    KBody(text: "A Key Holder is a friend who can let you out of a Locked session. They need Lock In too (free). You pair once, in person.")
                    TextField("Your first name", text: $keys.myName)
                        .font(PrintFont.body(17))
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(KInk.panel))
                        .foregroundStyle(KInk.cream)
                    Button("PAIR WITH A FRIEND NEARBY") { pairing = true }
                        .buttonStyle(PrintButtonStyle(fill: KInk.green, text: KInk.bg))
                        .disabled(keys.myName.trimmingCharacters(in: .whitespaces).isEmpty)

                    section("They can let me out", keys.holders, remove: keys.removeHolder)
                    section("I can let them out", keys.friends, remove: keys.removeFriend)

                    if !keys.friends.isEmpty {
                        Button("LET A FRIEND OUT (IN PERSON)") { helping = true }
                            .buttonStyle(PrintButtonStyle(fill: KInk.cream, text: KInk.bg))
                        ForEach(pending) { p in
                            PendingAskCard(keys: keys, pending: p) { pending.removeAll { $0.id == p.id } }
                        }
                    }
                }
                .padding(24)
            }
            .background(KInk.bg.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: done) } }
            .navigationDestination(isPresented: $pairing) { PairView(keys: keys) }
            .navigationDestination(isPresented: $helping) { HelpNearbyView(keys: keys) }
            .task { pending = (try? await RemoteKeys.pending(for: keys)) ?? [] }
        }
        .preferredColorScheme(.dark)
    }

    private func section(_ title: String, _ people: [KeyPerson], remove: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(PrintFont.mono(12, .heavy)).tracking(1.5).foregroundStyle(KInk.green)
            if people.isEmpty {
                Text("Nobody yet.").font(PrintFont.body(15)).foregroundStyle(KInk.cream.opacity(0.5))
            }
            ForEach(people) { person in
                HStack {
                    Image(systemName: "key.fill").foregroundStyle(KInk.green)
                    Text(person.name).font(PrintFont.bold(19)).foregroundStyle(KInk.cream)
                    Spacer()
                    Button("Remove") { remove(person.id) }
                        .font(PrintFont.body(14)).foregroundStyle(KInk.alarm)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(KInk.panel))
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Pairing

private struct PairView: View {
    @ObservedObject var keys: KeyStore
    @StateObject private var link: NearbyLink
    @State private var role: Role = .holder
    @State private var saved = false

    enum Role { case holder, friend }

    init(keys: KeyStore) {
        self.keys = keys
        _link = StateObject(wrappedValue: NearbyLink(card: keys.myCard))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KTitle(text: "Pair in\nperson.")
                KBody(text: "Both of you open Keys and tap Pair. Keep the phones close.")
                Picker("Role", selection: $role) {
                    Text("They hold my key").tag(Role.holder)
                    Text("I hold their key").tag(Role.friend)
                }
                .pickerStyle(.segmented)
                if let card = link.peerCard {
                    Text("Found \(card.name).").font(PrintFont.bold(24)).foregroundStyle(KInk.cream)
                    Button(saved ? "PAIRED" : (role == .holder ? "MAKE \(card.name.uppercased()) MY KEY HOLDER" : "HOLD \(card.name.uppercased())\u{2019}S KEY")) {
                        if role == .holder { keys.addHolder(card) } else { keys.addFriend(card) }
                        saved = true
                    }
                    .buttonStyle(PrintButtonStyle(fill: saved ? KInk.panel : KInk.green, text: saved ? KInk.cream : KInk.bg))
                    .disabled(saved)
                    KBody(text: "Your friend picks the other option on their phone.")
                } else {
                    HStack(spacing: 10) {
                        ProgressView().tint(KInk.green)
                        Text("Looking for your friend\u{2019}s phone\u{2026}").font(PrintFont.body(16)).foregroundStyle(KInk.cream)
                    }
                }
            }
            .padding(24)
        }
        .background(KInk.bg.ignoresSafeArea())
        .onAppear { link.start() }
        .onDisappear { link.stop() }
    }
}

// MARK: - Asking in person (the locked person's phone)

struct InPersonUnlockView: View {
    @ObservedObject var keys: KeyStore
    let sessionID: UUID
    let onApproved: () -> Void
    @StateObject private var link: NearbyLink
    @State private var reason = ""
    @State private var ask: UnlockAsk?
    @State private var verdict: String?

    init(keys: KeyStore, sessionID: UUID, onApproved: @escaping () -> Void) {
        self.keys = keys
        self.sessionID = sessionID
        self.onApproved = onApproved
        _link = StateObject(wrappedValue: NearbyLink(card: keys.myCard))
    }

    private var holder: KeyPerson? {
        guard let card = link.peerCard else { return nil }
        return keys.holders.first { $0.id == card.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KTitle(text: "Ask your\nKey Holder.")
                KBody(text: "They open Lock In, go to Keys, and tap \u{201C}Let a friend out\u{201D}. Phones close together.")
                TextField("Why do you need out?", text: $reason, axis: .vertical)
                    .font(PrintFont.body(17))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(KInk.panel))
                    .foregroundStyle(KInk.cream)
                status
                if let holder, link.isClose, ask == nil {
                    Button("ASK \(holder.name.uppercased())") {
                        let a = newAsk(keys: keys, holder: holder, sessionID: sessionID, reason: reason)
                        ask = a
                        link.send(ask: a)
                    }
                    .buttonStyle(PrintButtonStyle(fill: KInk.green, text: KInk.bg))
                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let verdict {
                    Text(verdict).font(PrintFont.bold(22)).foregroundStyle(KInk.alarm)
                }
            }
            .padding(24)
        }
        .onAppear { link.start() }
        .onDisappear { link.stop() }
        .onChange(of: link.answer) { _, answer in
            guard let answer, let ask, let holder else { return }
            if approved(answer, for: ask, by: holder) {
                onApproved()
            } else {
                verdict = "\(holder.name) said no. Keep going."
                self.ask = nil
            }
        }
    }

    @ViewBuilder private var status: some View {
        let line: String = {
            guard let card = link.peerCard else { return "Looking for your Key Holder\u{2019}s phone\u{2026}" }
            guard keys.holders.contains(where: { $0.id == card.id }) else { return "\(card.name) does not hold your key." }
            if !link.isClose, let d = link.distance { return String(format: "Come closer (%.1f m).", d) }
            if !link.isClose { return "Come closer." }
            return ask == nil ? "\(card.name) is here." : "Waiting for \(card.name) to decide\u{2026}"
        }()
        HStack(spacing: 10) {
            if link.peerCard == nil || ask != nil { ProgressView().tint(KInk.green) }
            Text(line).font(PrintFont.body(16)).foregroundStyle(KInk.cream)
        }
    }
}

// MARK: - Letting a friend out in person (the Key Holder's phone)

private struct HelpNearbyView: View {
    @ObservedObject var keys: KeyStore
    @StateObject private var link: NearbyLink
    @State private var answered = false

    init(keys: KeyStore) {
        self.keys = keys
        _link = StateObject(wrappedValue: NearbyLink(card: keys.myCard))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KTitle(text: "Let a\nfriend out.")
                KBody(text: "Keep your phones close. Their request shows up here.")
                if let ask = link.incomingAsk, let friend = keys.friends.first(where: { $0.id == ask.from }),
                   KeyStore.verify(ask.signature, of: KeyStore.requestText(requestID: ask.requestID, from: ask.from, to: ask.to,
                                                                          sessionID: ask.sessionID, nonce: ask.nonce), by: friend),
                   ask.to == keys.myID {
                    if answered {
                        Text("Sent.").font(PrintFont.bold(22)).foregroundStyle(KInk.green)
                    } else {
                        DecisionCard(name: friend.name, reason: ask.reason) { yes in
                            let sig = keys.sign(KeyStore.answerText(requestID: ask.requestID, nonce: ask.nonce, approved: yes))
                            link.send(answer: UnlockAnswer(requestID: ask.requestID, nonce: ask.nonce, approved: yes, signature: sig))
                            answered = true
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        ProgressView().tint(KInk.green)
                        Text(link.peerCard.map { "\($0.name) is here. Waiting for their request\u{2026}" } ?? "Looking for your friend\u{2019}s phone\u{2026}")
                            .font(PrintFont.body(16)).foregroundStyle(KInk.cream)
                    }
                }
            }
            .padding(24)
        }
        .background(KInk.bg.ignoresSafeArea())
        .onAppear { link.start() }
        .onDisappear { link.stop() }
    }
}

/// "Let them out?" Hold to say yes, so it is a choice, not a reflex.
private struct DecisionCard: View {
    let name: String
    let reason: String
    let decide: (Bool) -> Void
    @State private var fill: CGFloat = 0
    @State private var done = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Let \(name) out?").font(PrintFont.head(36)).foregroundStyle(KInk.cream)
            Text("\u{201C}\(reason.isEmpty ? "No reason given." : reason)\u{201D}")
                .font(PrintFont.body(17)).foregroundStyle(KInk.cream.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            ZStack(alignment: .leading) {
                Capsule().fill(KInk.panel)
                GeometryReader { g in Rectangle().fill(KInk.green).frame(width: g.size.width * fill) }
                Text(done ? "LET OUT" : "HOLD TO LET OUT").font(PrintFont.bold(18)).tracking(2)
                    .foregroundStyle(KInk.cream).frame(maxWidth: .infinity)
            }
            .frame(height: 58)
            .clipShape(Capsule())
            .onLongPressGesture(minimumDuration: 2, maximumDistance: 60) {
                done = true
                decide(true)
            } onPressingChanged: { pressing in
                guard !done else { return }
                if pressing { withAnimation(.linear(duration: 2)) { fill = 1 } }
                else { withAnimation(.easeOut(duration: 0.3)) { fill = 0 } }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hold to let \(name) out")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Let out") { done = true; decide(true) }
            Button("KEEP THEM LOCKED") { decide(false) }
                .buttonStyle(PrintButtonStyle(fill: KInk.alarm, text: KInk.cream))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(KInk.panel.opacity(0.6)))
    }
}

/// A request that came in through iCloud.
struct PendingAskCard: View {
    @ObservedObject var keys: KeyStore
    let pending: RemoteKeys.Pending
    let finished: () -> Void
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DecisionCard(name: pending.name, reason: pending.ask.reason) { yes in
                Task {
                    do {
                        try await RemoteKeys.reply(to: pending.ask, approved: yes, keys: keys)
                        finished()
                    } catch {
                        self.error = "Could not send. Check iCloud and try again."
                    }
                }
            }
            if let error { Text(error).font(PrintFont.mono(12)).foregroundStyle(KInk.alarm) }
        }
    }
}

// MARK: - Asking from far away (iCloud)

struct RemoteAskView: View {
    @ObservedObject var keys: KeyStore
    let sessionID: UUID
    let onApproved: () -> Void
    @State private var holderID: String?
    @State private var reason = ""
    @State private var ask: UnlockAsk?
    @State private var sentAt: Date?
    @State private var approvedAt: Date?
    @State private var message: String?

    private var holder: KeyPerson? { keys.holders.first { $0.id == (holderID ?? keys.holders.first?.id) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KTitle(text: "Ask from\nfar away.")
                KBody(text: "They get a notification with your reason. If they say yes, your session ends 10 minutes later. No answer in 30 minutes means no.")
                if keys.holders.count > 1 {
                    Picker("Key Holder", selection: Binding(get: { holder?.id ?? "" }, set: { holderID = $0 })) {
                        ForEach(keys.holders) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.segmented)
                }
                if ask == nil {
                    TextField("Why do you need out?", text: $reason, axis: .vertical)
                        .font(PrintFont.body(17))
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(KInk.panel))
                        .foregroundStyle(KInk.cream)
                    Button("SEND TO \((holder?.name ?? "").uppercased())") { send() }
                        .buttonStyle(PrintButtonStyle(fill: KInk.green, text: KInk.bg))
                        .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty || holder == nil)
                } else if let approvedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let left = max(0, Int(QuitRules.remoteCoolDown - context.date.timeIntervalSince(approvedAt)))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(holder?.name ?? "They") said yes.").font(PrintFont.bold(22)).foregroundStyle(KInk.green)
                            Text(String(format: "Ends in %d:%02d", left / 60, left % 60))
                                .font(PrintFont.head(56)).monospacedDigit().foregroundStyle(KInk.cream)
                            KBody(text: "Still in the zone? You can keep going.")
                        }
                        .onChange(of: left) { _, now in if now == 0 { onApproved() } }
                    }
                } else {
                    HStack(spacing: 10) {
                        ProgressView().tint(KInk.green)
                        Text("Waiting for \(holder?.name ?? "them")\u{2026}").font(PrintFont.body(16)).foregroundStyle(KInk.cream)
                    }
                }
                if let message { Text(message).font(PrintFont.bold(20)).foregroundStyle(KInk.alarm) }
            }
            .padding(24)
        }
        .task(id: ask?.requestID) { await poll() }
    }

    private func send() {
        guard let holder else { return }
        let a = newAsk(keys: keys, holder: holder, sessionID: sessionID, reason: reason)
        message = nil
        Task {
            do {
                try await RemoteKeys.send(a, myName: keys.myCard.name, to: holder)
                ask = a
                sentAt = .now
            } catch {
                message = "Could not send. Make sure you are signed in to iCloud."
            }
        }
    }

    /// Checks for an answer every 5 seconds while this screen is open.
    private func poll() async {
        guard let ask, let holder else { return }
        while !Task.isCancelled && approvedAt == nil {
            if let sentAt, Date.now.timeIntervalSince(sentAt) > QuitRules.remoteTimeout {
                message = "No answer in 30 minutes. Keep going."
                self.ask = nil
                return
            }
            if let answer = try? await RemoteKeys.answer(for: ask.requestID) {
                if approved(answer, for: ask, by: holder) {
                    approvedAt = .now
                } else {
                    message = "\(holder.name) said no. Keep going."
                    self.ask = nil
                }
                return
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }
}
