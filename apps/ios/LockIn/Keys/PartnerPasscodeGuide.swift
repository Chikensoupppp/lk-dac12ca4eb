import SwiftUI

/// Extra security (Plus): the accountability partner puts a Screen Time passcode on the user's phone,
/// so the user can't switch Screen Time off and get around SwipeLater. SwipeLater can't set or read
/// that passcode (it's Apple's, in Settings); this only walks the two of them through it.
/// Brandon, 2026-11-20: needs iOS 26.4 or later, so older phones are told to update first.
/// Laid out like Apple's own setup sheets (2026-11-21): an icon tile, a centred title, grouped cards.
struct PartnerPasscodeGuide: View {
    let done: () -> Void

    private static let ink = Ink.ink
    private static let soft = Ink.ink.opacity(0.55)
    private static let tint = Ink.blue
    private static let green = Color(hex: 0x2F9E55)

    /// iOS 26.4 or later.
    static var supported: Bool {
        if #available(iOS 26.4, *) { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Done", action: done)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Self.tint)
                        .frame(minWidth: 44, minHeight: 44)
                }

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Self.tint))
                    .padding(.top, 6)
                    .accessibilityHidden(true)

                Text("Let Your Partner Lock Screen Time")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(Self.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
                    .accessibilityAddTraits(.isHeader)

                Text("They set a Screen Time passcode on your iPhone that only they know. Then you can\u{2019}t switch Screen Time off to get around SwipeLater.")
                    .font(.system(size: 17))
                    .foregroundStyle(Self.soft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .padding(.horizontal, 8)

                versionRow
                    .padding(.top, 24)

                Text("HOW TO SET IT UP")
                    .font(.system(size: 13))
                    .foregroundStyle(Self.soft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 7)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    step(1, "Open **Settings** and tap **Screen Time**.")
                    divider
                    step(2, "Tap **Lock Screen Time Settings**.")
                    divider
                    step(3, "Hand your iPhone to your partner. **They** enter a 4-digit code. Don\u{2019}t watch.")
                    divider
                    step(4, "If it asks for an Apple Account to reset the code, your partner can use theirs, or tap **Cancel**.")
                    divider
                    step(5, "That\u{2019}s it. Turning off Screen Time now needs their code.")
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))

                Text("SwipeLater never sees or stores this code. To change it later, ask your partner.")
                    .font(.system(size: 13))
                    .foregroundStyle(Self.soft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 20)
        }
        .background(Ink.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    /// A row that says this phone is on iOS 26.4 or later, or how to update first.
    private var versionRow: some View {
        let ok = Self.supported
        return HStack(spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(ok ? Self.green : Ink.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(ok ? "This iPhone is ready" : "Requires iOS 26.4 or later")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Self.ink)
                Text(ok ? "iOS \(UIDevice.current.systemVersion)"
                        : "This iPhone has iOS \(UIDevice.current.systemVersion). Update in Settings > General > Software Update.")
                    .font(.system(size: 15))
                    .foregroundStyle(Self.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(Self.ink.opacity(0.14)).frame(height: 0.5).padding(.leading, 56)
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Self.tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Self.tint.opacity(0.12)))
            Text(text)
                .font(.system(size: 17))
                .foregroundStyle(Self.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
