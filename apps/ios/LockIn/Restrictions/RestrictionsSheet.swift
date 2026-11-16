import FamilyControls
import ManagedSettings
import SwiftUI

/// The warm paper look of the Shielded apps sheet (2026-11-16 design).
private enum SInk {
    static let page = Color(hex: 0xF4F1EA)
    static let ink = Color(hex: 0x171513)
    static let soft = Color(hex: 0x6F6A60)
    static let line = Color(hex: 0xE4DED3)
    static let trackOff = Color(hex: 0xDDD7CB)
}

/// One row: a thing the user chose in Apple's picker. Apple shows the real name and icon only
/// through a Label, so the row uses it; the app never sees the names itself.
private enum Shielded: Hashable {
    case app(ApplicationToken)
    case category(ActivityCategoryToken)
    case site(WebDomainToken)
}

/// Screen Time controls: which apps stay closed during a lock-in. Reports only what the framework
/// reported; it never claims enforcement it has not applied.
struct RestrictionsSheet: View {
    @ObservedObject var restrictions: RestrictionController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var picking = false
    /// Rows stay on screen when switched off, so they can be switched back on.
    @State private var rows: [Shielded] = []

    private var hasAccess: Bool {
        switch restrictions.status {
        case .needsAuthorization, .denied, .failed: return false
        default: return true
        }
    }

    private var headline: String {
        switch restrictions.status {
        case .needsAuthorization: return "Screen Time access is off"
        case .denied: return "Screen Time access was denied"
        case .ready: return "Access granted"
        case .active: return "Shields are on for this session"
        case .skipped(.tooShort): return "Sessions under 15 minutes run without shields"
        case .skipped(.notAuthorized): return "Shields were skipped: no access"
        case .skipped(.noSelection): return "Shields were skipped: no apps chosen"
        case .skipped(.alreadyExpired): return "Shields were skipped: session already over"
        case .failed(let message): return "Screen Time problem: \(message)"
        }
    }

    private var chosenCount: Int {
        let s = restrictions.selection
        return s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
    }

    var body: some View {
        ZStack(alignment: .top) {
            SInk.page.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 17))
                        .foregroundStyle(SInk.ink)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Color.white.opacity(0.7)))
                        .overlay(Capsule().stroke(SInk.line, lineWidth: 1))
                }
                .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("RESTRICTIONS")
                            .font(.system(size: 17, weight: .semibold))
                            .tracking(3.4)
                            .foregroundStyle(SInk.soft)
                            .padding(.top, 18)
                            .accessibilityHidden(true)
                        Text("Shielded apps.")
                            .font(.system(size: 46, weight: .heavy))
                            .tracking(-1.6)
                            .foregroundStyle(SInk.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 18)
                            .accessibilityAddTraits(.isHeader)
                        HStack(spacing: 12) {
                            if hasAccess {
                                Image(systemName: "checkmark").font(.system(size: 18, weight: .medium))
                            }
                            Text(headline)
                                .font(.system(size: 21))
                                .accessibilityIdentifier("restrictions-status")
                        }
                        .foregroundStyle(SInk.soft)
                        .padding(.top, 26)
                        .padding(.bottom, 24)

                        Rectangle().fill(SInk.line).frame(height: 1)
                        ForEach(rows, id: \.self) { item in row(item) }
                    }
                }
                .scrollIndicators(.hidden)

                Spacer(minLength: 12)
                action
                Text("Shielded apps stay closed during a lock-in, on this phone.")
                    .font(.system(size: 18))
                    .foregroundStyle(SInk.soft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)
                    .padding(.bottom, 12)
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
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SInk.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SwitchPill(on: Binding(get: { isOn(item) }, set: { set(item, on: $0) }))
            }
            .padding(.vertical, 20)
            Rectangle().fill(SInk.line).frame(height: 1)
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
            pill(chosenCount == 0 ? "CHOOSE APPS" : "SHIELD \(chosenCount) APP\(chosenCount == 1 ? "" : "S")",
                 id: chosenCount == 0 ? "Choose apps to shield" : "Change chosen apps") { picking = true }
        }
    }

    private func pill(_ title: String, id: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title)
                .font(.system(size: 22, weight: .medium))
                .tracking(3)
                .foregroundStyle(SInk.page)
                .frame(maxWidth: .infinity, minHeight: 68)
                .background(Capsule().fill(SInk.ink))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(id)
    }
}

/// The black switch from the design: a pill track with a white knob.
private struct SwitchPill: View {
    @Binding var on: Bool

    var body: some View {
        Button { on.toggle() } label: {
            Capsule()
                .fill(on ? SInk.ink : SInk.trackOff)
                .frame(width: 88, height: 52)
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle().fill(Color.white).frame(width: 44, height: 44).padding(4)
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                }
                .animation(.easeOut(duration: 0.16), value: on)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Shield")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}
