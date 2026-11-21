import SwiftUI

/// Extra security (Plus): the accountability partner puts a Screen Time passcode on the user's phone,
/// so the user can't switch Screen Time off and get around SwipeLater. SwipeLater can't set or read
/// that passcode (it's Apple's, in Settings); this only walks the two of them through it.
/// Brandon, 2026-11-20: needs iOS 26.4 or later, so older phones are told to update first.
struct PartnerPasscodeGuide: View {
    let done: () -> Void

    /// iOS 26.4 or later.
    static var supported: Bool {
        if #available(iOS 26.4, *) { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: done) {
                        Text("Done")
                            .font(PrintFont.bold(17)).tracking(1.5)
                            .foregroundStyle(Ink.ink)
                            .padding(.horizontal, 20)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(Ink.receipt))
                            .overlay(Capsule().stroke(Ink.ink, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                HStack(spacing: 8) {
                    PlusBadge()
                    Text("EXTRA SECURITY").font(PrintFont.mono(11, .bold)).tracking(1.4).foregroundStyle(Ink.blue)
                }
                .padding(.top, 14)

                Text("LET YOUR PARTNER\nLOCK SCREEN TIME.")
                    .font(PrintFont.head(UIScreen.main.bounds.height < 700 ? 38 : 46))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Let your partner lock Screen Time")

                Text("They set a Screen Time passcode on your phone that only they know. Then you can\u{2019}t switch Screen Time off to get around SwipeLater.")
                    .font(PrintFont.body(16, .medium))
                    .foregroundStyle(Ink.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                versionCard.padding(.top, 18)

                VStack(alignment: .leading, spacing: 0) {
                    step(1, "Open the **Settings** app and tap **Screen Time**.")
                    divider
                    step(2, "Tap **Lock Screen Time Settings**.")
                    divider
                    step(3, "Hand your phone to your partner. **They** type a 4-digit code. Don\u{2019}t watch.")
                    divider
                    step(4, "If it asks for an Apple Account to reset the code, your partner can use theirs, or tap **Cancel**.")
                    divider
                    step(5, "Done. Turning off Screen Time now needs their code.")
                }
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.8)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Ink.ink.opacity(0.15), lineWidth: 1.5))
                .padding(.top, 18)

                Text("SwipeLater never sees or stores this code. If you ever need it changed, ask your partner.")
                    .font(PrintFont.mono(12))
                    .foregroundStyle(Ink.soft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 24)
        }
        .background(Ink.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    /// Green when this phone is on iOS 26.4 or later; otherwise how to update first.
    private var versionCard: some View {
        let ok = Self.supported
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ok ? Color(hex: 0x2F8F4E) : Ink.red)
            VStack(alignment: .leading, spacing: 3) {
                Text(ok ? "Your iPhone is ready" : "Needs iOS 26.4 or later")
                    .font(PrintFont.bold(17)).foregroundStyle(Ink.ink)
                Text(ok ? "This iPhone has iOS \(UIDevice.current.systemVersion)."
                        : "This iPhone has iOS \(UIDevice.current.systemVersion). Update in Settings > General > Software Update, then come back.")
                    .font(PrintFont.body(14, .medium))
                    .foregroundStyle(Ink.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(ok ? Color(hex: 0xE3F1E6) : Color(hex: 0xF8E3DE)))
        .accessibilityElement(children: .combine)
    }

    private var divider: some View { Rectangle().fill(Ink.ink.opacity(0.1)).frame(height: 1) }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(PrintFont.bold(14))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Ink.blue))
            Text(text)
                .font(PrintFont.body(15.5, .medium))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
