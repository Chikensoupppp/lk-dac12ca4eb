import StoreKit
import SwiftUI

/// Links the offer slide needs. Apple requires working Terms and Privacy links on a subscription
/// screen. Terms uses Apple's standard license until Lock In has its own.
enum PlusLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// The public privacy policy (swipelater-site repo, privacy/index.html). Nil would hide the link.
    static let privacy: URL? = URL(string: "https://swipelater.app/privacy/")
}

/// The Plus offer: the last slide of the first run, and the sheet behind the Locked mode switch.
/// A member card rises in and gets its LOCKED IN stamp, what Plus adds pops in, one plan is picked,
/// and an honest trial timeline with real dates. Prices come from the App Store. An easy "Not now",
/// and Restore / Terms / Privacy. Mock: docs/design/paywall-v2.html.
struct PlusOfferStep: View {
    @ObservedObject var plus: PlusStore
    /// Last slide of the first run (true) or the sheet behind the Locked mode switch (false).
    var intro = true
    let next: () -> Void

    @State private var cardIn = false
    @State private var stamped = false
    @State private var shine = false
    @State private var rows = 0
    @State private var plansIn = false
    @State private var stops = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.openURL) private var openURL

    private static let softInk = Color(hex: 0x3F413B)

    private var buttonTitle: String {
        if plus.isPlus { return "CONTINUE" }
        switch plus.loadState {
        case .loading: return "LOADING..."
        case .unavailable: return "NOT ON SALE YET"
        case .ready:
            if let days = plus.trialDays { return "TRY \(days) DAYS FREE" }
            return "GET PLUS"
        }
    }

    private var buttonEnabled: Bool {
        plus.isPlus || (plus.loadState == .ready && !plus.busy)
    }

    var body: some View {
        PrintScaffold(step: OnboardingFlow.stepCount - 1, tag: "SwipeLater Plus", title: "Lock in\nfor real.", titleSize: 40,
                      primaryTitle: buttonTitle, primaryEnabled: buttonEnabled, primaryAction: buy,
                      footer: AnyView(footer)) {
            VStack(alignment: .leading, spacing: 12) {
                card
                    .padding(.horizontal, 6)
                    .rotationEffect(.degrees(cardIn ? -2 : -10))
                    .scaleEffect(cardIn ? 1 : 0.8, anchor: .bottom)
                    .offset(y: cardIn ? 0 : 120)
                    .opacity(cardIn ? 1 : 0)
                VStack(alignment: .leading, spacing: 8) {
                    feature(0, symbol: "lock.fill", color: Ink.blue, glyph: .white,
                            title: "Locked mode", line: "No quit button. It runs to the end.")
                    feature(1, symbol: "person.2.fill", color: Ink.sun, glyph: Ink.ink,
                            title: "A friend holds the key", line: "They end it early. Or 1 emergency exit a week.")
                    feature(2, symbol: "calendar", color: Ink.red, glyph: .white,
                            title: "Every week, saved", line: "Your whole history, not just 3 weeks.")
                }
                if plus.isPlus {
                    Text("You have Plus. Thank you.")
                        .font(PrintFont.bold(22))
                        .foregroundStyle(Ink.ink)
                } else if plus.loadState == .unavailable {
                    Text("Plus is not on sale yet. Everything you set up stays free.")
                        .font(PrintFont.bold(19))
                        .foregroundStyle(Ink.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if plus.yearly != nil || plus.monthly != nil { planPicker }
                        timeline
                    }
                    .opacity(plansIn ? 1 : 0)
                    .offset(y: plansIn ? 0 : 14)
                }
                if let message = plus.message {
                    Text(message).font(PrintFont.mono(12)).foregroundStyle(Self.softInk)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: stamped)
        .task { await play() }
    }

    // MARK: The card

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let year = Calendar.current.component(.year, from: .now)
        return ZStack(alignment: .topLeading) {
            shape.fill(Ink.blue)
            Canvas { ctx, size in
                // Halftone dots, like the riso print on the rest of the slides.
                for x in stride(from: 4.5, to: size.width, by: 9) {
                    for y in stride(from: 4.5, to: size.height, by: 9) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 1.4, y: y - 1.4, width: 2.8, height: 2.8)),
                                 with: .color(.white.opacity(0.16)))
                    }
                }
            }
            // Flexible height (scaled, not sized) so the shine never makes the card taller than its
            // frame: a fixed 260 pt here centered the content and cut "PLUS" off the top.
            LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 70)
                .frame(maxHeight: .infinity)
                .scaleEffect(y: 2)
                .rotationEffect(.degrees(18))
                .offset(x: shine ? 420 : -140)
            VStack(alignment: .leading, spacing: 0) {
                Text("MEMBER CARD")
                    .font(PrintFont.mono(10, .bold)).tracking(1.8)
                    .opacity(0.8)
                Text("PLUS")
                    .font(PrintFont.head(34))
                    .padding(.top, 4)
                Spacer(minLength: 0)
                Text("SWIPELATER \u{00B7} \(String(year))")
                    .font(PrintFont.mono(12)).tracking(2)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(16)
            Image("BrainExact")
                .resizable()
                .scaledToFit()
                .frame(width: 88)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -6, y: 10)
            Text(plus.isPlus ? "ACTIVE" : "LOCKED IN")
                .font(PrintFont.head(22))
                .tracking(1)
                .foregroundStyle(Ink.sun)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 10).fill(Ink.ink.opacity(0.18)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Ink.sun, lineWidth: 3))
                .rotationEffect(.degrees(-9))
                .scaleEffect(stamped ? 1 : 2.2)
                .opacity(stamped ? 1 : 0)
                .offset(x: 104, y: 30)
        }
        .frame(height: 112)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 6))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plus.isPlus ? "SwipeLater Plus member card, active" : "SwipeLater Plus member card")
    }

    private func feature(_ i: Int, symbol: String, color: Color, glyph: Color, title: String, line: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(glyph)
                .frame(width: 34, height: 34)
                .background(Circle().fill(color))
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
                .background(Circle().fill(Ink.ink).offset(y: 3))
                .scaleEffect(rows > i ? 1 : 0.6)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(PrintFont.bold(16)).foregroundStyle(Ink.ink)
                Text(line)
                    .font(PrintFont.body(13, .medium))
                    .foregroundStyle(Self.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(rows > i ? 1 : 0)
        .offset(x: rows > i ? 0 : -16)
        .accessibilityElement(children: .combine)
    }

    // MARK: Plans and the timeline

    /// Yearly (with the free trial) or monthly. Prices come from the App Store.
    private var planPicker: some View {
        HStack(spacing: 10) {
            if let yearly = plus.yearly {
                planChip(id: PlusStore.yearlyID, title: "Yearly", price: yearly.displayPrice,
                         note: perMonth(yearly).map { "\($0) a month" } ?? "Best value",
                         badge: plus.trialDays(for: yearly).map { "\($0) DAYS FREE" })
            }
            if let monthly = plus.monthly {
                planChip(id: PlusStore.monthlyID, title: "Monthly", price: monthly.displayPrice,
                         note: plus.trialDays(for: monthly).map { "\($0) days free" } ?? "No free trial", badge: nil)
            }
        }
        .padding(.top, 8)
    }

    private func perMonth(_ product: Product) -> String? {
        guard product.subscription?.subscriptionPeriod.unit == .year else { return nil }
        return (product.price / 12).formatted(product.priceFormatStyle)
    }

    private func planChip(id: String, title: String, price: String, note: String, badge: String?) -> some View {
        let on = plus.selectedID == id
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button { plus.selectedID = id } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased()).font(PrintFont.mono(11, .bold)).tracking(1.2).foregroundStyle(Self.softInk)
                Text(price).font(PrintFont.head(26)).foregroundStyle(Ink.ink)
                Text(note).font(PrintFont.body(12, .semibold)).foregroundStyle(Self.softInk)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .padding(.horizontal, 13)
            .background(shape.fill(Color.white))
            .overlay(shape.strokeBorder(on ? Ink.ink : Ink.ink.opacity(0.18), lineWidth: 2))
            .background(shape.fill(Ink.ink).offset(y: on ? 4 : 0))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(PrintFont.mono(9, .bold)).tracking(1)
                        .foregroundStyle(Ink.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Ink.sun))
                        .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2))
                        .offset(x: -10, y: -11)
                }
            }
            .animation(.easeOut(duration: 0.15), value: on)
        }
        .buttonStyle(.plain)
        .accessibilityLabel([title, price, note, badge?.lowercased()].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    /// Today / reminder day / charge day, with real dates. The reminder is the local notification
    /// `PlusStore` schedules two days before the trial ends.
    @ViewBuilder
    private var timeline: some View {
        if let days = plus.trialDays, let price = plus.priceLine {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .top) {
                    GeometryReader { g in
                        Capsule().fill(Ink.ink.opacity(0.15)).frame(height: 3)
                        Capsule().fill(Ink.ink).frame(width: g.size.width * min(CGFloat(stops) / 3, 1), height: 3)
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    HStack(alignment: .top) {
                        stop(0, icon: "checkmark", fill: Ink.blue, glyph: .white,
                             title: "Today", line: "All of Plus, free", align: .leading)
                        Spacer(minLength: 4)
                        stop(1, icon: "bell.fill", fill: Ink.sun, glyph: Ink.ink,
                             title: dayTitle(max(days - 2, 1)), line: "We remind you", align: .center)
                        Spacer(minLength: 4)
                        stop(2, icon: "dollarsign", fill: .white, glyph: Ink.ink,
                             title: dayTitle(days), line: price, align: .trailing)
                    }
                }
                legal("Free for \(days) days, then \(price). Renews automatically until you cancel in Settings.")
            }
        } else if let price = plus.priceLine {
            legal("\(price). Renews automatically until you cancel in Settings.")
        }
    }

    private func stop(_ i: Int, icon: String, fill: Color, glyph: Color, title: String, line: String,
                      align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(glyph)
                .frame(width: 26, height: 26)
                .background(Circle().fill(fill))
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
                .scaleEffect(stops > i ? 1 : 0.5)
                .padding(.bottom, 2)
            Text(title).font(PrintFont.bold(15)).foregroundStyle(Ink.ink)
            Text(line).font(PrintFont.body(13, .semibold)).foregroundStyle(Self.softInk)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .multilineTextAlignment(align == .leading ? .leading : align == .trailing ? .trailing : .center)
        .opacity(stops > i ? 1 : 0)
        .accessibilityElement(children: .combine)
    }

    private func legal(_ text: String) -> some View {
        Text(text)
            .font(PrintFont.body(11, .medium))
            .foregroundStyle(Self.softInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func dayTitle(_ day: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: day, to: .now) ?? .now
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: Footer and actions

    private var footer: some View {
        HStack(spacing: 20) {
            if !plus.isPlus {
                Button(action: next) { Text("Not now").fontWeight(.bold).foregroundStyle(Ink.ink) }
            }
            Button("Restore") { Task { await plus.restore() } }
            Button("Terms") { openURL(PlusLinks.terms) }
            if let privacy = PlusLinks.privacy {
                Button("Privacy") { openURL(privacy) }
            }
        }
        .font(PrintFont.body(14))
        .foregroundStyle(Ink.ink.opacity(0.7))
        .frame(minHeight: 44)
    }

    private func play() async {
        if intro { UserDefaults.standard.set(true, forKey: "lockin.plusOffered.v1") }
        if effectiveReduceMotion(systemReduceMotion) {
            cardIn = true; stamped = true; rows = 3; plansIn = true; stops = 3
            return
        }
        guard await printPause(0.15) else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) { cardIn = true }
        guard await printPause(0.7) else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.5)) { stamped = true }
        guard await printPause(0.15) else { return }
        withAnimation(.easeInOut(duration: 0.8)) { shine = true }
        for i in 1...3 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { rows = i }
            guard await printPause(0.15) else { return }
        }
        withAnimation(.easeOut(duration: 0.35)) { plansIn = true }
        guard await printPause(0.3) else { return }
        for i in 1...3 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { stops = i }
            guard await printPause(0.22) else { return }
        }
    }

    private func buy() {
        if plus.isPlus { next(); return }
        Task {
            if await plus.purchase() { next() }
        }
    }
}
