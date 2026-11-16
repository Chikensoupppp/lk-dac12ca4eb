import SwiftUI

private enum KInk {
    // Riso newsprint, same as the slides and the main screen (2026-11-13).
    static let bg = Color(hex: 0xE7E8E3)
    static let panel = Color(hex: 0xF3F4F0)
    /// Main text (the name is from the old dark look, where text was cream).
    static let cream = Color(hex: 0x1B1B1B)
    /// The action color: riso Medium Blue.
    static let green = Color(hex: 0x3255A4)
    static let alarm = Color(hex: 0xD25A44)
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

// MARK: - Accountability partner sheet (from the main screen)

/// The warm paper look of the partner sheet (2026-11-15 design): cream page, near-black ink, one black pill.
private enum PInk {
    static let page = Color(hex: 0xF4F1EA)
    static let ink = Color(hex: 0x171513)
    static let soft = Color(hex: 0x6F6A60)
    static let line = Color(hex: 0xE4DED3)
    static let dash = Color(hex: 0xC4BDB0)
    static let alarm = Color(hex: 0xB3402E)
}

/// Pair with a friend in person, see who can let you out (and whom you can let out), and let a friend out.
struct KeysSheet: View {
    @ObservedObject var keys: KeyStore
    let done: () -> Void
    @State private var pairRole: PairView.Role?
    @State private var helping = false
    @State private var askingName = false
    @State private var nameDraft = ""
    @State private var wantedRole: PairView.Role = .holder
    @State private var pending: [RemoteKeys.Pending] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Accountability partner.")
                        .font(.system(size: 44, weight: .heavy))
                        .tracking(-1.4)
                        .foregroundStyle(PInk.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("A friend who can let you out of a lock-in.")
                        .font(.system(size: 20))
                        .foregroundStyle(PInk.soft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)

                    Button { startPairing(.holder) } label: {
                        Text("PAIR A FRIEND")
                            .font(.system(size: 18, weight: .medium))
                            .tracking(2.4)
                            .foregroundStyle(PInk.page)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Capsule().fill(PInk.ink))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 28)
                    .accessibilityIdentifier("partner-pair")

                    Rectangle().fill(PInk.line).frame(height: 1).padding(.top, 28)
                    rows(keys.holders, empty: "Can let you out", role: .holder, remove: keys.removeHolder)
                    rows(keys.friends, empty: "You can let them out", role: .friend, remove: keys.removeFriend)

                    if !keys.friends.isEmpty {
                        Button { helping = true } label: {
                            Text("LET A FRIEND OUT")
                                .font(.system(size: 16, weight: .medium))
                                .tracking(2)
                                .foregroundStyle(PInk.ink)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .overlay(Capsule().stroke(PInk.ink, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 24)
                        ForEach(pending) { p in
                            PendingAskCard(keys: keys, pending: p) { pending.removeAll { $0.id == p.id } }
                                .padding(.top, 12)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(PInk.page.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: done) } }
            .navigationDestination(item: $pairRole) { role in PairView(keys: keys, role: role) }
            .navigationDestination(isPresented: $helping) { HelpNearbyView(keys: keys) }
            .task { pending = (try? await RemoteKeys.pending(for: keys)) ?? [] }
            .alert("Your first name", isPresented: $askingName) {
                TextField("First name", text: $nameDraft)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) {}
                Button("Next") {
                    let name = nameDraft.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    keys.myName = name
                    pairRole = wantedRole
                }
            } message: {
                Text("Your friend sees this name.")
            }
        }
        .preferredColorScheme(.light)
    }

    /// Pairing needs a name the friend will see; ask for it once, the first time.
    private func startPairing(_ role: PairView.Role) {
        wantedRole = role
        if keys.myName.trimmingCharacters(in: .whitespaces).isEmpty {
            nameDraft = ""
            askingName = true
        } else {
            pairRole = role
        }
    }

    @ViewBuilder
    private func rows(_ people: [KeyPerson], empty: String, role: PairView.Role, remove: @escaping (String) -> Void) -> some View {
        if people.isEmpty {
            row(mark: Image(systemName: "plus").font(.system(size: 14, weight: .medium)).foregroundStyle(PInk.soft),
                dashed: true, title: "Nobody yet", detail: empty) {
                Button("Invite") { startPairing(role) }
                    .font(.system(size: 19))
                    .foregroundStyle(PInk.ink)
                    .underline()
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        ForEach(people) { person in
            row(mark: Text(String(person.name.prefix(1)).uppercased()).font(.system(size: 20, weight: .semibold)).foregroundStyle(PInk.ink),
                dashed: false, title: person.name, detail: empty) {
                Button("Remove") { remove(person.id) }
                    .font(.system(size: 17))
                    .foregroundStyle(PInk.alarm)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    private func row<Mark: View, Action: View>(mark: Mark, dashed: Bool, title: String, detail: String,
                                               @ViewBuilder action: () -> Action) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 22) {
                ZStack {
                    Circle()
                        .strokeBorder(PInk.dash, style: StrokeStyle(lineWidth: 1.2, dash: dashed ? [3, 3] : []))
                        .frame(width: 58, height: 58)
                    mark
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 22, weight: .semibold)).foregroundStyle(PInk.ink)
                    Text(detail).font(.system(size: 17)).foregroundStyle(PInk.soft)
                }
                Spacer(minLength: 8)
                action()
            }
            .padding(.vertical, 20)
            Rectangle().fill(PInk.line).frame(height: 1)
        }
    }
}

// MARK: - Pairing

private struct PairView: View {
    @ObservedObject var keys: KeyStore
    @StateObject private var link: NearbyLink
    @State private var role: Role
    @State private var saved = false

    enum Role: Hashable { case holder, friend }

    init(keys: KeyStore, role: Role = .holder) {
        self.keys = keys
        _role = State(initialValue: role)
        _link = StateObject(wrappedValue: NearbyLink(card: keys.myCard))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                KTitle(text: "Pair in\nperson.")
                KBody(text: "Both of you open Accountability partner and tap Pair a friend. Keep the phones close.")
                Picker("Role", selection: $role) {
                    Text("They can let me out").tag(Role.holder)
                    Text("I can let them out").tag(Role.friend)
                }
                .pickerStyle(.segmented)
                if let card = link.peerCard {
                    Text("Found \(card.name).").font(PrintFont.bold(24)).foregroundStyle(KInk.cream)
                    Button(saved ? "PAIRED" : (role == .holder ? "MAKE \(card.name.uppercased()) MY PARTNER" : "BE \(card.name.uppercased())\u{2019}S PARTNER")) {
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
                KTitle(text: "Ask your\npartner.")
                KBody(text: "They open Nogbox, go to Accountability partner, and tap \u{201C}Let a friend out\u{201D}. Phones close together.")
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
            guard let card = link.peerCard else { return "Looking for your partner\u{2019}s phone\u{2026}" }
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
                    Picker("Partner", selection: Binding(get: { holder?.id ?? "" }, set: { holderID = $0 })) {
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
