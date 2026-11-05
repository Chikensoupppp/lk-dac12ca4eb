import SwiftUI

/// One quiet line under the title. Idle: a tappable "PAIR A PC" or the PC's state. In a session: state only.
struct PCStatusLine: View {
    @ObservedObject var pc: PCLink
    let isLocked: Bool
    let open: () -> Void

    private var label: String? {
        switch pc.status {
        case .notPaired: return isLocked ? nil : "PAIR A PC"
        case .paired: return "PC PAIRED"
        case .connected: return "PC CONNECTED"
        case .offline: return "PC OFFLINE, RETRYING"
        }
    }

    var body: some View {
        if let label {
            if isLocked {
                Text(label)
                    .font(Cream.rounded(12, .semibold))
                    .tracking(2)
                    .foregroundStyle(Matte.textSoft)
                    .padding(.top, 4)
                    .accessibilityIdentifier("pc-status")
            } else {
                Button(action: open) {
                    Text(label)
                        .font(Cream.rounded(12, .semibold))
                        .tracking(2)
                        .foregroundStyle(Matte.textSoft)
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("pc-status")
            }
        }
    }
}

struct PCSheet: View {
    @ObservedObject var pc: PCLink
    @Environment(\.dismiss) private var dismiss
    @State private var scanning = false

    private var headline: String {
        if pc.isPairing { return "Pairing with your PC..." }
        switch pc.status {
        case .notPaired: return "No PC is paired."
        case .paired: return "PC paired."
        case .connected: return "Connected to your PC."
        case .offline: return "The PC is not answering."
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CreamBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(headline)
                            .font(Cream.rounded(26, .light))
                            .foregroundStyle(Cream.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("pc-headline")

                        if let problem = pc.problem {
                            Text(problem)
                                .font(Cream.rounded(15, .medium))
                                .foregroundStyle(Cream.inkSoft)
                                .accessibilityIdentifier("pc-problem")
                        }

                        Button { scanning = true } label: { Text("SCAN QR CODE") }
                            .buttonStyle(CreamButtonStyle(prominent: !pc.isPaired))
                            .disabled(pc.isPairing)
                            .accessibilityLabel("Scan the pairing QR code")

                        if pc.isPaired {
                            Button { pc.forget() } label: { Text("FORGET THIS PC") }
                                .buttonStyle(CreamButtonStyle(prominent: false))
                                .accessibilityLabel("Forget this PC")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("PC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Cream.rounded(17, .semibold))
                        .foregroundStyle(Cream.quietText)
                }
            }
            .fullScreenCover(isPresented: $scanning) {
                QRScannerScreen(
                    onCode: { text in
                        scanning = false
                        guard let offer = PCPairingOffer.decode(text) else {
                            pc.report("That QR code is not from Lock In.")
                            return
                        }
                        Task { await pc.pair(offer: offer) }
                    },
                    onCancel: { scanning = false })
            }
        }
        .preferredColorScheme(.light)
    }
}
