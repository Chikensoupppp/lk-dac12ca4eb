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
    @AppStorage(PCSheet.buddyKey) private var buddy = true
    @AppStorage(PCSheet.remindKey) private var remindMinutes = PCSheet.remindDefault

    static let buddyKey = "lockin.pc.buddy.v1"
    /// The desk buddy is on unless the user turned it off.
    static var buddyOn: Bool { UserDefaults.standard.object(forKey: buddyKey) as? Bool ?? true }

    static let remindKey = "lockin.pc.remindMinutes.v1"
    static let remindDefault = 3
    static let remindRange = 1...10
    /// How many minutes of steady scrolling the buddy watches before it says something.
    static var remindAfter: Int {
        let stored = UserDefaults.standard.object(forKey: remindKey) as? Int ?? remindDefault
        return min(max(stored, remindRange.lowerBound), remindRange.upperBound)
    }

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
                FocusBackdrop(timing: nil, flash: nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(headline)
                            .font(Cream.rounded(26, .light))
                            .foregroundStyle(Matte.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("pc-headline")

                        if let problem = pc.problem {
                            Text(problem)
                                .font(Cream.rounded(15, .medium))
                                .foregroundStyle(Matte.textSoft)
                                .accessibilityIdentifier("pc-problem")
                        }

                        Button { scanning = true } label: { Text("SCAN QR CODE") }
                            .buttonStyle(MatteButtonStyle(prominent: !pc.isPaired))
                            .disabled(pc.isPairing)
                            .accessibilityLabel("Scan the pairing QR code")

                        if pc.isPaired {
                            Toggle(isOn: $buddy) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Desk buddy")
                                        .font(Cream.rounded(17, .semibold))
                                        .foregroundStyle(Matte.text)
                                    Text("Your brain sits in the corner of the PC screen.")
                                        .font(Cream.rounded(14, .medium))
                                        .foregroundStyle(Matte.textSoft)
                                }
                            }
                            .tint(Matte.riso)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("pc-buddy")

                            if buddy {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Scroll reminder")
                                            .font(Cream.rounded(17, .semibold))
                                            .foregroundStyle(Matte.text)
                                        Spacer()
                                        Text("after \(remindMinutes) min")
                                            .font(Cream.rounded(15, .medium))
                                            .foregroundStyle(Matte.textSoft)
                                            .monospacedDigit()
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { Double(remindMinutes) },
                                            set: { remindMinutes = Int($0.rounded()) }),
                                        in: Double(PCSheet.remindRange.lowerBound)...Double(PCSheet.remindRange.upperBound),
                                        step: 1)
                                    .tint(Matte.riso)
                                    .accessibilityLabel("Scroll reminder")
                                    .accessibilityValue("after \(remindMinutes) minutes of scrolling")
                                }
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("pc-remind-after")
                            }

                            Button { pc.forget() } label: { Text("FORGET THIS PC") }
                                .buttonStyle(MatteButtonStyle(prominent: false))
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
                        .foregroundStyle(Matte.textQuiet)
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
