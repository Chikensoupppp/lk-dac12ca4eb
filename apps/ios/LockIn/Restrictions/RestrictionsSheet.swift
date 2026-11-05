import FamilyControls
import SwiftUI

/// Short state of Screen Time controls. It reports only what the framework
/// reported; it never claims enforcement it has not applied.
struct RestrictionsSheet: View {
    @ObservedObject var restrictions: RestrictionController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var picking = false

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
                CreamBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Text(headline)
                            .font(Cream.rounded(26, .light))
                            .foregroundStyle(Cream.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("restrictions-status")

                        action
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
                        .font(Cream.rounded(13, .bold))
                        .tracking(4)
                        .foregroundStyle(Cream.inkSoft)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Cream.rounded(17, .semibold))
                        .foregroundStyle(Cream.quietText)
                }
            }
            .familyActivityPicker(
                isPresented: $picking,
                selection: Binding(get: { restrictions.selection }, set: { restrictions.setSelection($0) })
            )
        }
        .preferredColorScheme(.light)
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
            .buttonStyle(CreamButtonStyle(prominent: true))
            .accessibilityLabel("Allow Screen Time access")
        case .denied:
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Text("OPEN SETTINGS")
            }
            .buttonStyle(CreamButtonStyle(prominent: true))
            .accessibilityLabel("Open iOS Settings")
        default:
            Button {
                picking = true
            } label: {
                Text(restrictions.hasSelection ? "CHANGE APPS" : "CHOOSE APPS")
            }
            .buttonStyle(CreamButtonStyle(prominent: !restrictions.hasSelection))
            .accessibilityLabel(restrictions.hasSelection ? "Change chosen apps" : "Choose apps to shield")
        }
    }
}
