import SwiftUI

// Screens for leaving a session early. All use the heart-monitor look of the brain.

private enum QuitInk {
    // Riso newsprint, same as the slides and the main screen (2026-11-13).
    static let bg = Color(hex: 0xE7E8E3)
    static let panel = Color(hex: 0xF3F4F0)
    /// Main text (the name is from the old dark look, where text was cream).
    static let cream = Color(hex: 0x1B1B1B)
    /// The action color: riso Medium Blue.
    static let green = Color(hex: 0x3255A4)
    static let alarm = Color(hex: 0xD25A44)

    /// Wait bar and heart number: blue while calm, sunflower when tired, red at the end.
    static func level(_ stage: Int) -> Color {
        switch stage {
        case 4, 5: return alarm
        case 3: return Color(hex: 0xC98A00)
        default: return green
        }
    }
}

/// A wait that only counts while this screen is open and the app is in front. Leave and it starts
/// over. Used only by the emergency exit. Nothing on screen gets worse while it runs.
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
            let stage = 0
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
                        Capsule().fill(QuitInk.level(stage)).frame(width: g.size.width * progress)
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)
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

/// Free sessions: ending early is one calm choice. The time already focused still counts.
struct QuitSheet: View {
    let focusedMinutes: Int
    let onQuit: () -> Void
    let onStay: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("End this\nsession?")
                    .font(PrintFont.head(52))
                    .foregroundStyle(QuitInk.cream)
                    .accessibilityAddTraits(.isHeader)
                Text(focusedMinutes > 0
                     ? "You focused \(FocusLog.format(minutes: focusedMinutes)). That time counts."
                     : "No problem. You can start again any time.")
                    .font(PrintFont.body(18))
                    .foregroundStyle(QuitInk.cream.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("quit-focused-line")
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Pinned to the bottom so the buttons are always reachable, even at large text sizes.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button { onStay() } label: { Text("KEEP GOING").lineLimit(1).minimumScaleFactor(0.7) }
                    .buttonStyle(PrintButtonStyle(fill: QuitInk.green, text: QuitInk.bg))
                    .accessibilityIdentifier("quit-keep-going")
                Button { onQuit() } label: { Text("End session").lineLimit(1).minimumScaleFactor(0.7) }
                    .font(PrintFont.body(17, .semibold))
                    .foregroundStyle(QuitInk.cream)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityIdentifier("quit-end-session")
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(QuitInk.bg)
        }
        .background(QuitInk.bg.ignoresSafeArea())
        .preferredColorScheme(.light)
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
        .preferredColorScheme(.light)
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

/// Proof Check: Screen Time access was turned off in Settings during a session. The shields are
/// gone. The user can turn it back on and get the shields back.
struct ProofBrokenSheet: View {
    let turnBackOn: () async -> Bool
    let onClose: () -> Void
    @State private var working = false
    @State private var failed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("SCREEN TIME OFF")
                    .font(PrintFont.mono(13))
                    .tracking(2)
                    .foregroundStyle(QuitInk.alarm)
                Text("Screen Time\nwas turned off.")
                    .font(PrintFont.head(52))
                    .foregroundStyle(QuitInk.cream)
                Text("Your apps are not locked right now. Turn it back on to keep them quiet, or carry on without.")
                    .font(PrintFont.body(16))
                    .foregroundStyle(QuitInk.cream.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                if failed {
                    Text("Still off. Allow Lock In when iPhone asks.")
                        .font(PrintFont.mono(12))
                        .foregroundStyle(QuitInk.alarm)
                }
                Button(working ? "ASKING..." : "TURN IT BACK ON") {
                    working = true
                    Task {
                        let ok = await turnBackOn()
                        working = false
                        if ok { onClose() } else { failed = true }
                    }
                }
                .buttonStyle(PrintButtonStyle(fill: QuitInk.green, text: QuitInk.bg))
                .disabled(working)
                .padding(.top, 6)
                Button("Keep going without shields") { onClose() }
                    .font(PrintFont.body(15))
                    .foregroundStyle(QuitInk.cream.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(QuitInk.bg.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}
