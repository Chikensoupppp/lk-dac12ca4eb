import FamilyControls
import ManagedSettings
import SwiftUI

/// One row: a thing the user chose in Apple's picker. Apple shows the real name and icon only
/// through a Label, so the row uses it; the app never sees the names itself.
private enum Shielded: Hashable {
    case app(ApplicationToken)
    case category(ActivityCategoryToken)
    case site(WebDomainToken)
}

/// The words for the chosen apps. "Locked" only while a session's shields are really on; otherwise
/// the apps are open and just waiting for the next session.
enum LockWords: Equatable {
    case pick, ready, locked

    init(chosen: Int, shieldsOn: Bool) {
        self = chosen == 0 ? .pick : (shieldsOn ? .locked : .ready)
    }

    var title: String {
        switch self {
        case .pick: return "Pick what\nto pause."
        case .ready: return "Ready\nto lock."
        case .locked: return "Locked."
        }
    }

    var line: String {
        switch self {
        case .pick: return "Choose the apps you want to block while you\u{2019}re focusing."
        case .ready: return "They lock when you start a session. Right now they\u{2019}re open."
        case .locked: return "They\u{2019}re blocked until your timer ends."
        }
    }

    func stamp(_ count: Int) -> String { self == .locked ? "\(count) locked" : "\(count) picked" }
}

/// Screen Time controls: which apps stay closed during a lock-in. Reports only what the framework
/// reported; it never claims enforcement it has not applied.
/// Same printed look as the onboarding "Which apps to block?" slide (LockAppsStep),
/// so the app has one way of choosing apps.
struct RestrictionsSheet: View {
    @ObservedObject var restrictions: RestrictionController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var picking = false
    /// Rows stay on screen when switched off, so they can be switched back on.
    @State private var rows: [Shielded] = []
    @State private var appeared = false
    @State private var shareStats = Analytics.consent == true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One shared entrance: fade and rise, in order. With Reduce Motion it is a fade only.
    private func enter(_ index: Int) -> some ViewModifier {
        Entrance(shown: appeared, index: index, still: reduceMotion)
    }

    /// "Access granted" is the normal state and says nothing new; only problems and lock news show.
    private var showHeadline: Bool {
        if case .ready = restrictions.status { return false }
        return true
    }

    private var headline: String {
        switch restrictions.status {
        case .needsAuthorization: return "Screen Time is off. Allow it so SwipeLater can lock your apps."
        case .denied: return "Screen Time access is blocked. Turn it on in Settings."
        case .ready: return "Screen Time is on."
        case .active: return "Your apps are locked right now."
        case .skipped(.tooShort): return "Sessions under 15 minutes don\u{2019}t lock apps."
        case .skipped(.notAuthorized): return "Your apps weren\u{2019}t locked: Screen Time is off."
        case .skipped(.noSelection): return "Your apps weren\u{2019}t locked: you haven\u{2019}t picked any yet."
        case .skipped(.alreadyExpired): return "Your apps weren\u{2019}t locked: the session was already over."
        case .failed(let message): return "Screen Time problem: \(message)"
        }
    }

    private var chosenCount: Int {
        let s = restrictions.selection
        return s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
    }

    private var words: LockWords { LockWords(chosen: chosenCount, shieldsOn: restrictions.status == .active) }

    private var titleSize: CGFloat { UIScreen.main.bounds.height < 700 ? 42 : 52 }

    var body: some View {
        ZStack(alignment: .top) {
            Ink.paper.ignoresSafeArea()
            Grain(color: Ink.ink.opacity(0.09)).ignoresSafeArea().allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(PrintFont.bold(17))
                        .tracking(1.5)
                        .foregroundStyle(Ink.ink)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Ink.receipt))
                        .overlay(Capsule().stroke(Ink.ink, lineWidth: 2))
                }
                .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(words.title.uppercased())
                            .font(PrintFont.head(titleSize))
                            .foregroundStyle(Ink.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 14)
                            .accessibilityAddTraits(.isHeader)
                            .modifier(enter(0))
                        Text(words.line)
                            .font(PrintFont.mono(14))
                            .foregroundStyle(Ink.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .modifier(enter(1))
                        Text("You can change your selection anytime.")
                            .font(PrintFont.mono(12))
                            .foregroundStyle(Ink.soft)
                            .modifier(enter(2))
                        if showHeadline {
                            Text(headline)
                                .font(PrintFont.mono(14))
                                .foregroundStyle(Ink.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("restrictions-status")
                                .modifier(enter(3))
                        }
                        if rows.isEmpty {
                            emptySlots
                        } else {
                            LockedStamp(count: chosenCount, words: words, still: reduceMotion)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        ForEach(rows, id: \.self) { item in
                            row(item)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 10)))
                        }
                    }
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                action
                Text("Locked apps stay closed during a lock-in, on this phone.")
                    .font(PrintFont.mono(12))
                    .foregroundStyle(Ink.soft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                if Analytics.consentRequired {
                    // Where a yes was needed, taking it back is just as easy.
                    HStack(spacing: 18) {
                        Text("Share usage stats")
                            .font(PrintFont.mono(13))
                            .foregroundStyle(Ink.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        SwitchPill(on: $shareStats, label: "Share usage stats")
                            .scaleEffect(0.8)
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            rows = currentRows()
            appeared = true
        }
        .onChange(of: shareStats) { _, on in Analytics.setConsent(on) }
        .onChange(of: restrictions.selection) { _, _ in
            // Picker changes add new rows; switched-off rows stay.
            withAnimation(.easeOut(duration: 0.25)) {
                for item in currentRows() where !rows.contains(item) { rows.append(item) }
            }
        }
        .familyActivityPicker(
            isPresented: $picking,
            selection: Binding(get: { restrictions.selection }, set: { restrictions.setSelection($0) })
        )
        .preferredColorScheme(.light)
    }

    private func currentRows() -> [Shielded] {
        let s = restrictions.selection
        return s.applicationTokens.map(Shielded.app) + s.categoryTokens.map(Shielded.category) + s.webDomainTokens.map(Shielded.site)
    }

    private func isOn(_ item: Shielded) -> Bool {
        let s = restrictions.selection
        switch item {
        case .app(let t): return s.applicationTokens.contains(t)
        case .category(let t): return s.categoryTokens.contains(t)
        case .site(let t): return s.webDomainTokens.contains(t)
        }
    }

    private func set(_ item: Shielded, on: Bool) {
        var s = restrictions.selection
        switch item {
        case .app(let t): if on { s.applicationTokens.insert(t) } else { s.applicationTokens.remove(t) }
        case .category(let t): if on { s.categoryTokens.insert(t) } else { s.categoryTokens.remove(t) }
        case .site(let t): if on { s.webDomainTokens.insert(t) } else { s.webDomainTokens.remove(t) }
        }
        restrictions.setSelection(s)
    }

    @ViewBuilder
    private func label(_ item: Shielded) -> some View {
        switch item {
        case .app(let t): Label(t).labelStyle(.titleAndIcon)
        case .category(let t): Label(t).labelStyle(.titleAndIcon)
        case .site(let t): Label(t).labelStyle(.titleAndIcon)
        }
    }

    private func row(_ item: Shielded) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                label(item)
                    .font(PrintFont.body(20))
                    .foregroundStyle(Ink.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SwitchPill(on: Binding(get: { isOn(item) }, set: { set(item, on: $0) }))
            }
            .padding(.vertical, 14)
            .opacity(isOn(item) ? 1 : 0.45)
            .animation(.easeOut(duration: 0.18), value: isOn(item))
            Rectangle().fill(Ink.ink.opacity(0.15)).frame(height: 1)
        }
    }

    /// Before anything is picked: the same dashed empty slots as the onboarding slide. They fill
    /// the page and show what is coming, and they appear one after another.
    private var emptySlots: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(0..<12, id: \.self) { i in
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Ink.ink.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(Image(systemName: "plus").foregroundStyle(Ink.ink.opacity(0.5)))
                    .modifier(Entrance(shown: appeared, index: 4 + i / 2, still: reduceMotion, scale: true))
            }
        }
        .padding(.top, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No apps chosen yet")
    }

    @ViewBuilder
    private var action: some View {
        switch restrictions.status {
        case .needsAuthorization, .failed:
            pill("ALLOW ACCESS", id: "Allow Screen Time access") { Task { await restrictions.requestAuthorization() } }
        case .denied:
            pill("OPEN SETTINGS", id: "Open iOS Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        default:
            pill(chosenCount == 0 ? "CHOOSE APPS" : "CHANGE APPS",
                 id: chosenCount == 0 ? "Choose apps to shield" : "Change chosen apps") { picking = true }
        }
    }

    private func pill(_ title: String, id: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) { Text(title) }
            .buttonStyle(PrintButtonStyle())
            .accessibilityLabel(id)
    }
}

/// Fade and rise, one item after the next (35 ms apart). Used once, when the sheet opens.
private struct Entrance: ViewModifier {
    let shown: Bool
    let index: Int
    let still: Bool
    var scale = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || still ? 0 : 12)
            .scaleEffect(scale && !shown && !still ? 0.9 : 1)
            .animation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.4).delay(Double(index) * 0.035), value: shown)
    }
}

/// The "N locked" stamp (blue, only while shields are on) or "N picked" (grey). It lands on the
/// page each time the count changes, like a real rubber stamp: a quick drop from a little larger, no bounce.
private struct LockedStamp: View {
    let count: Int
    let words: LockWords
    let still: Bool
    @State private var down = true

    var body: some View {
        Stamp(text: words.stamp(count), color: words == .locked ? Ink.blue : Ink.soft, size: 22, tilt: -5)
            .scaleEffect(down && !still ? 1.35 : 1)
            .opacity(down ? 0 : 1)
            .onAppear { land() }
            .onChange(of: count) { _, _ in
                down = true
                land()
            }
    }

    private func land() {
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.22)) { down = false }
    }
}

/// The black switch: a pill track with a paper knob, in the printed ink.
private struct SwitchPill: View {
    @Binding var on: Bool
    var label = "Lock"

    var body: some View {
        Button { on.toggle() } label: {
            Capsule()
                .fill(on ? Ink.ink : Ink.ink.opacity(0.18))
                .frame(width: 76, height: 44)
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle().fill(Ink.receipt).frame(width: 36, height: 36).padding(4)
                }
                .animation(.easeOut(duration: 0.16), value: on)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}
