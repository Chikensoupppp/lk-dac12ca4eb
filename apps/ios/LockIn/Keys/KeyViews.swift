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

/// The partner sheet in Apple's own style (Brandon, 2026-11-21: "make it more Apple design like"):
/// SF type, a large title, white grouped cards on the app's paper, Settings-style rows, text buttons.
private enum PInk {
    static let ink = Ink.ink
    static let soft = Ink.ink.opacity(0.55)
    static let tint = Ink.blue
    static let line = Ink.ink.opacity(0.14)
    static let card = Color.white
    static let ground = Ink.paper
    static let alarm = Ink.red
}

/// Pair with a friend in person, see who can let you out (and whom you can let out), and let a friend out.
/// Having a partner (someone who can let you out) is Plus; being someone's partner is free, so a
/// friend never needs Plus to help (Brandon, 2026-11-20: "make the key a Plus feature").
struct KeysSheet: View {
    @ObservedObject var keys: KeyStore
    @ObservedObject var plus: PlusStore
    let done: () -> Void
    @State private var showOffer = false
    @State private var showPasscode = false
    @State private var pairRole: PairView.Role?
    @State private var helping = false
    @State private var watching: KeyPerson?
    @State private var askingName = false
    @State private var nameDraft = ""
    @State private var wantedRole: PairView.Role = .holder
    @State private var pending: [RemoteKeys.Pending] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Done", action: done)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(PInk.tint)
                            .frame(minWidth: 44, minHeight: 44)
                    }

                    Text("Accountability Partner")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(PInk.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("A friend who can let you out of a lock-in.")
                        .font(.system(size: 17))
                        .foregroundStyle(PInk.soft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)

                    Button { startPairing(.holder) } label: {
                        Text("Pair a Friend")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(PInk.ink))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 22)
                    .accessibilityIdentifier("partner-pair")
                    if !plus.hasPlus {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            PlusPill()
                            Text("Being someone\u{2019}s Key Holder is free. Getting one of your own is Plus.")
                                .font(.system(size: 13))
                                .foregroundStyle(PInk.soft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 4)
                    }

                    sectionLabel("Your partner")
                        .padding(.top, 28)
                    card {
                        if keys.holders.isEmpty {
                            personRow(mark: Image(systemName: "person.badge.plus").font(.system(size: 16, weight: .medium)).foregroundStyle(PInk.soft),
                                      title: "Nobody yet", detail: "Pair in person, one tap each") {
                                Button("Invite") { startPairing(.holder) }
                                    .font(.system(size: 17))
                                    .foregroundStyle(PInk.tint)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                        }
                        ForEach(Array(keys.holders.enumerated()), id: \.element.id) { index, person in
                            if index > 0 { separator }
                            personRow(mark: initial(person.name), title: person.name, detail: "Can let you out") {
                                removeButton { keys.removeHolder(person.id) }
                            }
                        }
                    }

                    sectionLabel("How it works")
                        .padding(.top, 26)
                    card {
                        step(1, bold: "Pair in person", rest: ", one tap each")
                        separator
                        step(2, bold: "Ask", rest: " from the lock screen")
                        separator
                        step(3, bold: "They approve", rest: " and you\u{2019}re out")
                    }

                    // Extra security (Plus): the partner locks Screen Time with a passcode.
                    sectionLabel("Extra security")
                        .padding(.top, 26)
                    Button { if plus.hasPlus { showPasscode = true } else { showOffer = true } } label: {
                        card {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(PInk.tint))
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Lock Screen Time").font(.system(size: 17)).foregroundStyle(PInk.ink)
                                        PlusPill()
                                    }
                                    Text("Your partner sets a code, so you can\u{2019}t turn Screen Time off. iOS 26.4 or later.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(PInk.soft)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(PInk.soft.opacity(0.6))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("partner-passcode")

                    if !keys.friends.isEmpty {
                        sectionLabel("You can let out")
                            .padding(.top, 26)
                        card {
                            ForEach(Array(keys.friends.enumerated()), id: \.element.id) { index, person in
                                if index > 0 { separator }
                                personRow(mark: initial(person.name), title: person.name, detail: "You can let them out") {
                                    HStack(spacing: 14) {
                                        Button("See") { watching = person }
                                            .font(.system(size: 17))
                                            .foregroundStyle(PInk.tint)
                                            .frame(minWidth: 44, minHeight: 44)
                                            .accessibilityIdentifier("partner-see")
                                        removeButton { keys.removeFriend(person.id) }
                                    }
                                }
                            }
                        }
                        Button { helping = true } label: {
                            Text("Let a Friend Out")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(PInk.ink)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(PInk.ink.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 14)
                        ForEach(pending) { p in
                            PendingAskCard(keys: keys, pending: p) { pending.removeAll { $0.id == p.id } }
                                .padding(.top, 12)
                        }
                    }

                    Text("One partner at a time. You can unpair without asking them.")
                        .font(.system(size: 13))
                        .foregroundStyle(PInk.soft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(PInk.ground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $pairRole) { role in
                PairView(keys: keys, role: role, hasPlus: plus.hasPlus) { showOffer = true }
            }
            .navigationDestination(isPresented: $helping) { HelpNearbyView(keys: keys) }
            .navigationDestination(item: $watching) { person in
                PartnerWatchView(keys: keys, person: person) { watching = nil }
                    .navigationBarBackButtonHidden(true)
            }
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
            .sheet(isPresented: $showOffer) { PlusOfferStep(plus: plus, intro: false) { showOffer = false } }
            .sheet(isPresented: $showPasscode) { PartnerPasscodeGuide { showPasscode = false } }
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

    /// A grouped-list section header, like Settings: small grey capitals above a white card.
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13))
            .foregroundStyle(PInk.soft)
            .padding(.horizontal, 16)
            .padding(.bottom, 7)
            .accessibilityAddTraits(.isHeader)
    }

    /// A white grouped card; rows bring their own padding.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(PInk.card))
    }

    /// A hairline between rows, starting where the row's text starts.
    private var separator: some View {
        Rectangle().fill(PInk.line).frame(height: 0.5).padding(.leading, 68)
    }

    private func initial(_ name: String) -> some View {
        Text(String(name.prefix(1)).uppercased()).font(.system(size: 17, weight: .semibold)).foregroundStyle(PInk.ink)
    }

    private func removeButton(_ run: @escaping () -> Void) -> some View {
        Button("Remove", action: run)
            .font(.system(size: 17))
            .foregroundStyle(PInk.alarm)
            .frame(minWidth: 44, minHeight: 44)
    }

    private func personRow<Mark: View, Action: View>(mark: Mark, title: String, detail: String,
                                                     @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(PInk.ink.opacity(0.08)).frame(width: 40, height: 40)
                mark
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(PInk.ink)
                Text(detail).font(.system(size: 15)).foregroundStyle(PInk.soft)
            }
            Spacer(minLength: 8)
            action()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func step(_ number: Int, bold: String, rest: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PInk.tint)
                .frame(width: 40, height: 28)
                .background(Capsule().fill(PInk.tint.opacity(0.12)))
                .accessibilityHidden(true)
            (Text(bold).fontWeight(.semibold).foregroundColor(PInk.ink) + Text(rest).foregroundColor(PInk.soft))
                .font(.system(size: 17))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// A small "PLUS" pill in the Apple-style partner screens (the print screens use `PlusBadge`).
struct PlusPill: View {
    var body: some View {
        Text("PLUS")
            .font(.system(size: 11, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(Ink.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Ink.sun))
            .accessibilityLabel("Plus")
    }
}

// MARK: - Pairing

private struct PairView: View {
    @ObservedObject var keys: KeyStore
    @StateObject private var link: NearbyLink
    @State private var role: Role
    @State private var saved = false
    /// "They can let me out" (having a partner) needs Plus; "I can let them out" never does.
    let hasPlus: Bool
    let askPlus: () -> Void

    enum Role: Hashable { case holder, friend }

    init(keys: KeyStore, role: Role = .holder, hasPlus: Bool, askPlus: @escaping () -> Void) {
        self.keys = keys
        self.hasPlus = hasPlus
        self.askPlus = askPlus
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
                        // Having a partner is Plus: without it, this opens the offer instead.
                        if role == .holder && !hasPlus { askPlus(); return }
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
                KBody(text: "They open SwipeLater, go to Accountability partner, and tap \u{201C}Let a friend out\u{201D}. Phones close together.")
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
                KBody(text: "They get a notification with your reason. If they say yes, your session ends right away. No answer in 30 minutes means no.")
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
                } else if approvedAt != nil {
                    // A yes ends the session right away (Brandon, 2026-11-20; it used to wait 10 minutes).
                    Text("\(holder?.name ?? "They") said yes. You\u{2019}re out.")
                        .font(PrintFont.bold(22)).foregroundStyle(KInk.green)
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
                try await RemoteKeys.send(a, to: holder)
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
                    onApproved()
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
