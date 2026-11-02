import FamilyControls
import SwiftUI

/// Plain-language state of Screen Time controls. It reports only what the framework
/// reported; it never claims enforcement it has not applied.
struct RestrictionsSheet: View {
    @ObservedObject var restrictions: RestrictionController
    @Environment(\.dismiss) private var dismiss
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
            List {
                Section {
                    Text(headline)
                        .accessibilityIdentifier("restrictions-status")
                }
                Section {
                    switch restrictions.status {
                    case .needsAuthorization, .failed:
                        Button("Allow Screen Time access") {
                            Task { await restrictions.requestAuthorization() }
                        }
                    case .denied:
                        Text("Turn it on in Settings > Screen Time > Apps With Screen Time Access.")
                            .font(.footnote)
                    default:
                        Button(restrictions.hasSelection ? "Change chosen apps" : "Choose apps to shield") {
                            picking = true
                        }
                    }
                }
                Section("Limits") {
                    Text("Lock In shields only what you choose. Do not choose Phone or Messages if you need them.")
                    Text("This is a self-control aid, not tamper-proof. You can end a session any time, and you can remove access in iOS Settings.")
                    Text("Removal can lag the session end if Lock In is closed. iOS only reports the end when the device is in use.")
                }
                .font(.footnote)
            }
            .navigationTitle("Restrictions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .familyActivityPicker(
                isPresented: $picking,
                selection: Binding(get: { restrictions.selection }, set: { restrictions.setSelection($0) })
            )
        }
        .preferredColorScheme(.dark)
    }
}
