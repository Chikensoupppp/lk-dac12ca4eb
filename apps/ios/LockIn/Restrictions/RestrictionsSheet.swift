import FamilyControls
import SwiftUI

/// Plain-language state of Screen Time controls. It reports only what the framework
/// reported; it never claims enforcement it has not applied.
struct RestrictionsSheet: View {
    @ObservedObject var restrictions: RestrictionController
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false

    private static let limits = [
        "Lock In shields only what you choose. Do not choose Phone or Messages if you need them.",
        "This is a self-control aid, not tamper-proof. You can end a session any time, and you can remove access in iOS Settings.",
        "Removal can lag the session end if Lock In is closed. iOS only reports the end when the device is in use.",
    ]

    private var headline: String {
        switch restrictions.status {
        case .needsAuthorization: return "Screen Time access is off."
        case .denied: return "Screen Time access was denied."
        case .ready: return restrictions.hasSelection ? "Ready. Chosen apps are shielded during a session." : "Access granted. Choose apps to shield."
        case .active: return "Shields are on for this session."
        case .skipped(.tooShort): return "Sessions under 15 minutes run without shields."
        case .skipped(.notAuthorized): return "Shields were skipped: no access."
        case .skipped(.noSelection): return "Shields were skipped: no apps chosen."
        case .skipped(.alreadyExpired): return "Shields were skipped: session already over."
        case .failed(let message): return "Screen Time problem: \(message)"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FocusBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Text(headline)
                            .font(.system(.title3, design: .default, weight: .light))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("restrictions-status")

                        action

                        VStack(alignment: .leading, spacing: 12) {
                            Text("LIMITS")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(3)
                                .foregroundStyle(Color.white.opacity(0.45))
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(Self.limits.enumerated()), id: \.offset) { index, line in
                                    if index > 0 { Divider().overlay(Color.white.opacity(0.08)) }
                                    Text(line)
                                        .font(.footnote)
                                        .foregroundStyle(Color.white.opacity(0.62))
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Restrictions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("RESTRICTIONS")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(5)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            }
            .familyActivityPicker(
                isPresented: $picking,
                selection: Binding(get: { restrictions.selection }, set: { restrictions.setSelection($0) })
            )
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var action: some View {
        switch restrictions.status {
        case .needsAuthorization, .failed:
            Button {
                Task { await restrictions.requestAuthorization() }
            } label: {
                Text("ALLOW ACCESS")
            }
            .buttonStyle(TitaniumButtonStyle(prominent: true))
            .accessibilityLabel("Allow Screen Time access")
        case .denied:
            Text("Turn it on in Settings > Screen Time > Apps With Screen Time Access.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.62))
        default:
            Button {
                picking = true
            } label: {
                Text(restrictions.hasSelection ? "CHANGE APPS" : "CHOOSE APPS")
            }
            .buttonStyle(TitaniumButtonStyle(prominent: !restrictions.hasSelection))
            .accessibilityLabel(restrictions.hasSelection ? "Change chosen apps" : "Choose apps to shield")
        }
    }
}
