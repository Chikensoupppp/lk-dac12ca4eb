import StoreKit
import SwiftUI

/// Links the offer slide needs. Apple requires working Terms and Privacy links on a subscription
/// screen. Terms uses Apple's standard license until Lock In has its own.
enum PlusLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// TODO(Brandon): Lock In needs a privacy policy page before App Review. Nil hides the link.
    static let privacy: URL? = nil
}

/// The last slide: the offer, in a calm navy. An honest trial timeline with real dates, the price
/// from the App Store, an easy "Not now", and Restore / Terms / Privacy.
struct PlusOfferStep: View {
    @ObservedObject var plus: PlusStore
    /// Last slide of the first run (true) or the sheet behind the Locked mode switch (false).
    var intro = true
    let next: () -> Void
    @State private var cardIn = false
    @State private var rows = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.openURL) private var openURL

    private static let cream = Ink.paper

    private var buttonTitle: String {
        if plus.isPlus { return "CONTINUE" }
        switch plus.loadState {
        case .loading: return "LOADING..."
        case .unavailable: return "NOT ON SALE YET"
        case .ready: return plus.trialDays != nil ? "TRY FOR $0" : "GET PLUS"
        }
    }

    private var buttonEnabled: Bool {
        plus.isPlus || (plus.loadState == .ready && !plus.busy)
    }

    var body: some View {
        PrintScaffold(step: 12, background: Ink.navy, foreground: Self.cream, title: "Ready to\nlock in?",
                      primaryTitle: buttonTitle, primaryEnabled: buttonEnabled, primaryAction: buy,
                      secondaryTitle: plus.isPlus ? nil : "Not now", secondaryAction: next,
                      footer: AnyView(footer)) {
            VStack(alignment: .leading, spacing: 22) {
                if intro {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your first focus session is ready.")
                            .font(PrintFont.bold(20))
                            .foregroundStyle(Self.cream)
                        Text("One button. One thing to focus on.")
                            .font(PrintFont.body(15, .medium))
                            .foregroundStyle(Self.cream.opacity(0.8))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                card
                    .rotationEffect(.degrees(cardIn ? -4 : -14))
                    .scaleEffect(cardIn ? 1 : 0.6)
                    .opacity(cardIn ? 1 : 0)
                Text("Plus adds Locked mode: no quit button. Only your Key Holder, or one emergency exit a week, can end a session early.")
                    .font(PrintFont.body(15, .medium))
                    .foregroundStyle(Self.cream.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                if plus.isPlus {
                    Text("You have Plus. Thank you.")
                        .font(PrintFont.bold(22))
                        .foregroundStyle(Self.cream)
                } else {
                    timeline
                }
                if let message = plus.message {
                    Text(message).font(PrintFont.mono(12)).foregroundStyle(Self.cream.opacity(0.75))
                }
            }
        }
        .task {
            if effectiveReduceMotion(systemReduceMotion) { cardIn = true; rows = 3; return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { cardIn = true }
            guard await printPause(0.4) else { return }
            for i in 1...3 {
                withAnimation(.easeOut(duration: 0.3)) { rows = i }
                guard await printPause(0.25) else { return }
            }
        }
    }

    private var card: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Ink.blue, Color(hex: 0x1A2BB0)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .stroke(Color.white.opacity(0.13), lineWidth: 18)
                .frame(width: 180, height: 180)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 40, y: 60)
            Text("LOCK IN\nPLUS")
                .font(PrintFont.head(40))
                .lineSpacing(-6)
                .foregroundStyle(.white)
                .padding(20)
            Text(plus.isPlus ? "MEMBER \u{00B7} ACTIVE" : "MEMBER \u{00B7} SINCE TODAY")
                .font(PrintFont.mono(13))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(20)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.6), radius: 20, y: 18)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lock In Plus card")
    }

    /// Today / reminder day / charge day. Dates are real, counted from today.
    @ViewBuilder
    private var timeline: some View {
        if plus.loadState == .unavailable {
            Text("Plus is not on sale yet. Everything you set up stays free.")
                .font(PrintFont.bold(20))
                .foregroundStyle(Self.cream)
                .fixedSize(horizontal: false, vertical: true)
        } else if let days = plus.trialDays, let price = plus.priceLine {
            VStack(alignment: .leading, spacing: 16) {
                stop(0, filled: true, title: "Today", line: "Plus unlocked. $0.")
                stop(1, filled: false, title: dayTitle(max(days - 2, 1)), line: "We remind you.")
                stop(2, filled: false, title: dayTitle(days), line: "\(price). Cancel any time.")
            }
            Text("Free for \(days) days, then \(price). Renews automatically until you cancel in Settings.")
                .font(PrintFont.mono(10, .regular))
                .foregroundStyle(Self.cream.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        } else if let price = plus.priceLine {
            stop(0, filled: true, title: "Today", line: "\(price). Cancel any time.")
            Text("\(price). Renews automatically until you cancel in Settings.")
                .font(PrintFont.mono(10, .regular))
                .foregroundStyle(Self.cream.opacity(0.6))
        }
    }

    private func dayTitle(_ day: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: day, to: .now) ?? .now
        return "Day \(day) \u{00B7} " + date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func stop(_ i: Int, filled: Bool, title: String, line: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(filled ? Self.cream : Color.clear)
                .overlay(Circle().strokeBorder(Self.cream, lineWidth: 3))
                .frame(width: 22, height: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PrintFont.bold(19)).foregroundStyle(Self.cream)
                Text(line).font(PrintFont.mono(14, .medium)).foregroundStyle(Self.cream.opacity(0.75))
            }
        }
        .opacity(rows > i ? 1 : 0)
        .offset(x: rows > i ? 0 : -14)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Button("Restore") { Task { await plus.restore() } }
            Text("\u{00B7}")
            Button("Terms") { openURL(PlusLinks.terms) }
            if let privacy = PlusLinks.privacy {
                Text("\u{00B7}")
                Button("Privacy") { openURL(privacy) }
            }
        }
        .font(PrintFont.mono(11))
        .foregroundStyle(Self.cream.opacity(0.55))
        .frame(minHeight: 44)
    }

    private func buy() {
        if plus.isPlus { next(); return }
        Task {
            if await plus.purchase() { next() }
        }
    }
}
