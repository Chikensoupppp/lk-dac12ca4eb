import SwiftUI

// Screens for leaving a session early. All use the heart-monitor look of the brain.

private enum QuitInk {
    static let bg = BrainDrawing.bg
    static let panel = BrainDrawing.panel
    static let cream = BrainDrawing.cream
    static let green = BrainDrawing.green
    static let alarm = BrainDrawing.alarm
}

/// A wait that only counts while this screen is open and the app is in front. Leave and it starts
/// over. While it runs, the brain gets visibly worse and the heart rate climbs.
struct WatchedWait: View {
    let seconds: TimeInterval
    let done: () -> Void
    @State private var startedAt = Date.now
    @State private var finished = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: finished)) { context in
            let elapsed = finished ? seconds : min(seconds, context.date.timeIntervalSince(startedAt))
            let progress = seconds > 0 ? elapsed / seconds : 1
            let stage = min(5, Int(progress * 6))
            let left = max(0, Int((seconds - elapsed).rounded(.up)))
            let t = effectiveReduceMotion(systemReduceMotion) ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
            VStack(spacing: 14) {
                BrainCanvas(stage: stage, t: t)
                    .frame(height: 210)
                    .accessibilityHidden(true)
                Text(String(format: "%d:%02d", left / 60, left % 60))
                    .font(PrintFont.head(72))
                    .monospacedDigit()
                    .foregroundStyle(QuitInk.cream)
                    .accessibilityLabel("\(left) seconds left")
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(QuitInk.panel)
                        Capsule().fill(BrainDrawing.levelColor(stage)).frame(width: g.size.width * progress)
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)
                Text("\u{2665} \([72, 98, 126, 154, 188, 38][stage]) BPM")
                    .font(PrintFont.mono(13, .heavy))
                    .foregroundStyle(BrainDrawing.levelColor(stage))
            }
            .onChange(of: left) { _, now in
                if now == 0 && !finished {
                    finished = true
                    done()
                }
            }
        }
        // Leaving the app restarts the wait, so it cannot run in the background.
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the app starts the full wait again.
            if phase == .active && !finished { startedAt = .now }
        }
        .onAppear { startedAt = .now }
    }
}

/// Free users: quitting costs a watched wait, a typed sentence, and a scar on today's brain.
struct QuitSheet: View {
    let onQuit: () -> Void
    let onStay: () -> Void
    @State private var waited = false
    @State private var typed = ""
    @FocusState private var typing: Bool

    private let wait = QuitRules.nextQuitWait()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(waited ? "Say it." : "Still want\nto quit?")
                    .font(PrintFont.head(52))
                    .foregroundStyle(QuitInk.cream)
                if !waited {
                    Text("This wait only counts while you watch it. Leave the app and it starts over. Your apps stay locked.")
                        .font(PrintFont.body(16))
                        .foregroundStyle(QuitInk.cream.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    WatchedWait(seconds: wait) { withAnimation { waited = true } }
                    Text("Quit #\(QuitRules.quitsThisWeek() + 1) this week. Next one waits longer.")
                        .font(PrintFont.mono(12))
                        .foregroundStyle(QuitInk.cream.opacity(0.6))
                } else {
                    Text("Type this to end the session:")
                        .font(PrintFont.body(16))
                        .foregroundStyle(QuitInk.cream.opacity(0.8))
                    Text("\u{201C}\(QuitRules.sentence)\u{201D}")
                        .font(PrintFont.bold(24))
                        .foregroundStyle(QuitInk.alarm)
                    TextField("Type it here", text: $typed)
                        .font(PrintFont.body(17))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($typing)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(QuitInk.panel))
                        .foregroundStyle(QuitInk.cream)
                    Text("Your widget brain keeps a scar until tomorrow morning.")
                        .font(PrintFont.mono(12))
                        .foregroundStyle(QuitInk.cream.opacity(0.6))
                    Button("END SESSION") { onQuit() }
                        .buttonStyle(PrintButtonStyle(fill: QuitInk.alarm, text: QuitInk.cream))
                        .disabled(!QuitRules.matches(typed))
                        .opacity(QuitRules.matches(typed) ? 1 : 0.35)
                }
                Button("Keep going") { onStay() }
                    .buttonStyle(PrintButtonStyle(fill: QuitInk.green, text: QuitInk.bg))
                    .padding(.top, 6)
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(QuitInk.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onChange(of: waited) { _, now in if now { typing = true } }
    }
}

/// Plus "Locked" sessions: no quit button. The ways out.
struct LockedExitSheet: View {
    @ObservedObject var keys: KeyStore
    let sessionID: UUID
    let onExit: () -> Void
    let onStay: () -> Void
    @State private var route: Route?

    enum Route: Hashable { case inPerson, remote, emergency }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("This one\nis locked.")
                        .font(PrintFont.head(52))
                        .foregroundStyle(QuitInk.cream)
                    Text("You chose Locked mode. There is no quit button. These are the only ways out.")
                        .font(PrintFont.body(16))
                        .foregroundStyle(QuitInk.cream.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    option("person.2.fill", "My Key Holder is here", keys.holders.isEmpty ? "Add a Key Holder first (Keys)." : "Phones close together. They decide.",
                           enabled: !keys.holders.isEmpty) { route = .inPerson }
                    option("icloud.fill", "Ask my Key Holder from far away", keys.holders.isEmpty ? "Add a Key Holder first (Keys)." : "They get a message. If they say yes, it ends 10 minutes later.",
                           enabled: !keys.holders.isEmpty) { route = .remote }
                    option("exclamationmark.triangle.fill", "Emergency exit",
                           QuitRules.emergencyAvailable() ? "Once a week. A 15-minute wait you have to watch." : "Already used this week.",
                           enabled: QuitRules.emergencyAvailable()) { route = .emergency }
                    Button("Keep going") { onStay() }
                        .buttonStyle(PrintButtonStyle(fill: QuitInk.green, text: QuitInk.bg))
                        .padding(.top, 8)
                }
                .padding(24)
            }
            .background(QuitInk.bg.ignoresSafeArea())
            .navigationDestination(item: $route) { route in
                Group {
                    switch route {
                    case .inPerson: InPersonUnlockView(keys: keys, sessionID: sessionID, onApproved: onExit)
                    case .remote: RemoteAskView(keys: keys, sessionID: sessionID, onApproved: onExit)
                    case .emergency: EmergencyExitView(onExit: onExit)
                    }
                }
                .background(QuitInk.bg.ignoresSafeArea())
            }
        }
        .preferredColorScheme(.dark)
    }

    private func option(_ symbol: String, _ title: String, _ detail: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(QuitInk.green)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(PrintFont.bold(20)).foregroundStyle(QuitInk.cream)
                    Text(detail).font(PrintFont.body(14, .medium)).foregroundStyle(QuitInk.cream.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(QuitInk.cream.opacity(0.5))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(QuitInk.panel))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

/// Once a week: a 15-minute watched wait, then the session ends.
struct EmergencyExitView: View {
    let onExit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Emergency\nexit.")
                    .font(PrintFont.head(52))
                    .foregroundStyle(QuitInk.cream)
                Text("Stay on this screen. Leave the app and the 15 minutes start over. You get one a week.")
                    .font(PrintFont.body(16))
                    .foregroundStyle(QuitInk.cream.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                WatchedWait(seconds: QuitRules.emergencyWait) {
                    QuitRules.useEmergency()
                    onExit()
                }
            }
            .padding(24)
        }
    }
}
