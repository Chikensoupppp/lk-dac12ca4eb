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

/// Screen Time controls: which apps stay closed during a lock-in. Reports only what the framework
/// reported; it never claims enforcement it has not applied.
/// Same printed look and same words as the onboarding "Pick what to pause" slide (LockAppsStep),
/// so the app has one way of choosing apps.
struct RestrictionsSheet: View {
    @ObservedObject var restrictions: RestrictionController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var picking = false
    /// Rows stay on screen when switched off, so they can be switched back on.
    @State private var rows: [Shielded] = []

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
                        Text((chosenCount == 0 ? "Pick what\nto pause." : "Locked.").uppercased())
                            .font(PrintFont.head(titleSize))
                            .foregroundStyle(Ink.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 14)
                            .accessibilityAddTraits(.isHeader)
                        Text(chosenCount == 0
                             ? "Choose the apps you want to block while you\u{2019}re focusing."
                             : "They\u{2019}re blocked while your timer runs.")
                            .font(PrintFont.mono(14))
                            .foregroundStyle(Ink.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("You can change your selection anytime.")
                            .font(PrintFont.mono(12))
                            .foregroundStyle(Ink.soft)
                        if showHeadline {
                            Text(headline)
                                .font(PrintFont.mono(14))
                                .foregroundStyle(Ink.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("restrictions-status")
                        }
                        ForEach(rows, id: \.self) { item in row(item) }
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
            }
            .padding(.horizontal, 24)
        }
        .onAppear { rows = currentRows() }
        .onChange(of: restrictions.selection) { _, _ in
            // Picker changes add new rows; switched-off rows stay.
            for item in currentRows() where !rows.contains(item) { rows.append(item) }
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
            Rectangle().fill(Ink.ink.opacity(0.15)).frame(height: 1)
        }
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

/// The black switch: a pill track with a paper knob, in the printed ink.
private struct SwitchPill: View {
    @Binding var on: Bool

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
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Lock")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}
