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
                    .font(.system(size: 11, weight: .medium))
                    .tracking(3)
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.top, 4)
                    .accessibilityIdentifier("pc-status")
            } else {
                Button(action: open) {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .tracking(3)
                        .foregroundStyle(Color.white.opacity(0.55))
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
                FocusBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(headline)
                            .font(.system(.title3, design: .default, weight: .light))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("pc-headline")

                        if let problem = pc.problem {
                            Text(problem)
                                .font(.footnote)
                                .foregroundStyle(Color.white.opacity(0.7))
                                .accessibilityIdentifier("pc-problem")
                        }

                        Button { scanning = true } label: { Text("SCAN QR CODE") }
                            .buttonStyle(TitaniumButtonStyle(prominent: !pc.isPaired))
                            .disabled(pc.isPairing)
                            .accessibilityLabel("Scan the pairing QR code")

                        if pc.isPaired {
                            Button { pc.forget() } label: { Text("FORGET THIS PC") }
                                .buttonStyle(TitaniumButtonStyle(prominent: false))
                                .accessibilityLabel("Forget this PC")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("HOW TO PAIR")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(3)
                                .foregroundStyle(Color.white.opacity(0.45))
                            Text("1. On your PC, run LockIn.Companion.exe with the word --pair after it.\n2. A picture with a QR code opens. It works for 5 minutes.\n3. Tap SCAN QR CODE here and point the camera at it.\n\nBoth must be on the same Wi-Fi. If your PC is off, Lock In still works. It just will not start the PC.")
                                .font(.footnote)
                                .foregroundStyle(Color.white.opacity(0.62))
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
                        .foregroundStyle(Color.white.opacity(0.8))
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
        .preferredColorScheme(.dark)
    }
}
