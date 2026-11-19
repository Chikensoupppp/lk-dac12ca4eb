import SwiftUI

/// Slide 5: what your hours mean. One bar is your awake day (16 hours); the blue part is the phone,
/// with the share, the time left for you, an hour scale and week / month / year totals. Under it,
/// what that much time is enough for every day. The brain reacts. Mock: docs/design/day-bar-v2.html.
/// (The file keeps its old name; the heart monitor is gone.)
struct HeartBrainStep: View {
    let hoursIndex: Int
    let next: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduce: Bool { effectiveReduceMotion(systemReduceMotion) }

    /// 0...1: how far the bar has filled.
    @State private var fill: Double = 0
    @State private var chipsShown = false
    @State private var itemsShown = 0
    @State private var bubbleShown = false
    @State private var landed = 0
    @State private var bob = false

    private var band: Int { min(max(hoursIndex, 0), 3) }
    private var hours: Double { [1.5, 3.5, 5.5, 7.5][band] }
    private static let awake: Double = 16

    private static let titles = ["1\u{2013}2 hours\na day.", "3\u{2013}4 hours\na day.", "5\u{2013}6 hours\na day.", "7+ hours\na day."]
    private static let lines = [
        "A little more intentional time can go a long way.",
        "What would you do with a little of that time back?",
        "That\u{2019}s a lot of time. How much of it is really yours to choose?",
        "You don\u{2019}t have to change everything today. Start with 25 minutes."
    ]
    private static let says = ["Nice! Most of the day is still yours.", "Hmm. Want some of it back?",
                               "A third of your day? Oof.", "Half your day?! Let\u{2019}s fix this."]

    var body: some View {
        PrintScaffold(step: 5, title: Self.titles[band], titleSize: 46, grain: true,
                      primaryTitle: "CONTINUE", primaryAction: next) {
            VStack(alignment: .leading, spacing: 20) {
                ZStack(alignment: .topLeading) {
                    Text(Self.lines[band])
                        .font(PrintFont.bold(17))
                        .foregroundStyle(Ink.ink.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(bubbleShown ? 0 : 1)
                    if bubbleShown {
                        Bubble(text: Self.says[band])
                            .transition(.scale(scale: 0.7, anchor: .topTrailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // The brain sits in the empty space beside the headline.
                .overlay(alignment: .topTrailing) {
                    brain.offset(x: 4, y: -118)
                }

                card
                enough
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: landed)
        .task { await run() }
    }

    // MARK: The brain

    private var brain: some View {
        Image("BrainExact")
            .resizable()
            .scaledToFit()
            .frame(width: 104)
            .offset(y: bob ? -2 : 2)
            .keyframeAnimator(initialValue: CGFloat(0), trigger: landed) { content, s in
                content.scaleEffect(x: 1 + s, y: 1 - s, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0.09, duration: 0.08)
                    SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                }
            }
            .keyframeAnimator(initialValue: 0.0, trigger: bubbleShown) { content, a in
                content.rotationEffect(.degrees(a), anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(7, duration: 0.1)
                    CubicKeyframe(-6, duration: 0.12)
                    CubicKeyframe(4, duration: 0.12)
                    SpringKeyframe(0, duration: 0.3)
                }
            }
            .accessibilityHidden(true)
    }

    // MARK: The bar card

    private var card: some View {
        let minutes = hours * 60 * fill
        let share = hours / Self.awake
        let left = Self.awake * 60 - minutes
        return VStack(alignment: .leading, spacing: 0) {
            Text(Self.hm(minutes))
                .font(PrintFont.head(56))
                .monospacedDigit()
                .foregroundStyle(Ink.ink)
                .contentTransition(.numericText(value: minutes))
            Text("ON YOUR PHONE, OUT OF 16 HOURS AWAKE")
                .font(PrintFont.mono(10, .bold)).tracking(1.2)
                .foregroundStyle(Ink.ink.opacity(0.6))
                .padding(.top, 4)

            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white)
                    // One faint mark per hour.
                    Path { p in
                        for h in 1..<16 {
                            let x = w * CGFloat(h) / 16
                            p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: 36))
                        }
                    }
                    .stroke(Ink.ink.opacity(0.12), lineWidth: 2)
                    Rectangle()
                        .fill(Ink.blue)
                        .frame(width: max(0, w * CGFloat(share * fill)))
                        .overlay(alignment: .trailing) { Rectangle().fill(Ink.ink).frame(width: fill > 0 ? 2 : 0) }
                    Text("\(Int((share * fill * 100).rounded()))%")
                        .font(PrintFont.mono(12, .bold))
                        .foregroundStyle(.white)
                        .padding(.leading, 10)
                        .opacity(fill > 0.05 ? 1 : 0)
                    HStack {
                        Spacer()
                        Text("\(Self.hm(left)) LEFT FOR YOU")
                            .font(PrintFont.mono(10, .bold)).tracking(1)
                            .foregroundStyle(Ink.ink.opacity(0.6))
                            .padding(.horizontal, 4).padding(.vertical, 3)
                            .background(Color.white)
                            .padding(.trailing, 8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Ink.ink, lineWidth: 2))
            }
            .frame(height: 36)
            .padding(.top, 14)

            HStack {
                ForEach(["0H", "4H", "8H", "12H", "16H"], id: \.self) { l in
                    Text(l).font(PrintFont.mono(9, .semibold)).foregroundStyle(Ink.ink.opacity(0.55))
                    if l != "16H" { Spacer() }
                }
            }
            .padding(.top, 5)

            HStack(spacing: 8) {
                chip("EVERY WEEK", Self.hm(hours * 7 * 60, dropZeroMinutes: true), 0)
                chip("A MONTH, NONSTOP", "\(Int((hours * 30 / 24).rounded())) DAYS", 1)
                chip("A YEAR, NONSTOP", "\(Int((hours * 365 / 24).rounded())) DAYS", 2)
            }
            .padding(.top, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: 0xF4F4F0)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Ink.ink, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Ink.ink).offset(y: 5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.hm(hours * 60, spoken: true)) on your phone, \(Int((share * 100).rounded())) percent of 16 hours awake. Every week \(Self.hm(hours * 7 * 60, spoken: true)). In a year, \(Int((hours * 365 / 24).rounded())) full days.")
    }

    private func chip(_ label: String, _ value: String, _ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(PrintFont.mono(9, .bold)).tracking(1.1).foregroundStyle(Ink.ink.opacity(0.6))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(PrintFont.head(22)).foregroundStyle(Ink.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Ink.ink.opacity(0.14), lineWidth: 1.5))
        .opacity(chipsShown ? 1 : 0)
        .offset(y: chipsShown ? 0 : 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(i) * 0.08), value: chipsShown)
    }

    // MARK: What the time is enough for

    /// 45-minute episodes, about 40 pages an hour, 1-hour workouts.
    private var things: [(n: Int, one: String, many: String, symbol: String, fill: Color, glyph: Color)] {
        [
            (Int(hours * 60 / 45), "episode of a show", "episodes of a show", "play.fill", Color(hex: 0xE5484D), .white),
            (Int((hours * 40 / 10).rounded()) * 10, "page of a book", "pages of a book", "book.fill", Ink.sun, Ink.ink),
            (Int(hours), "gym session", "gym sessions", "dumbbell.fill", Ink.blue, .white)
        ]
    }

    private var enough: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EVERY DAY, THAT\u{2019}S ENOUGH TIME FOR")
                .font(PrintFont.mono(10, .bold)).tracking(1.6)
                .foregroundStyle(Ink.ink.opacity(0.6))
            ForEach(Array(things.enumerated()), id: \.offset) { i, t in
                let on = i < itemsShown
                HStack(spacing: 12) {
                    Image(systemName: t.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(t.glyph)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(t.fill))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Ink.ink, lineWidth: 2))
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Ink.ink).offset(y: 3))
                        .scaleEffect(on ? 1 : 0.6)
                        .rotationEffect(.degrees(on ? 0 : (i % 2 == 0 ? -5 : 5)))
                    Text("\(on ? t.n : 0)")
                        .font(PrintFont.head(28))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(on ? t.n : 0)))
                    Text(t.n == 1 ? t.one : t.many)
                        .font(PrintFont.bold(16))
                }
                .foregroundStyle(Ink.ink)
                .opacity(on ? 1 : 0)
                .offset(y: on ? 0 : 16)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Words

    static func hm(_ minutes: Double, dropZeroMinutes: Bool = false, spoken: Bool = false) -> String {
        let m = Int(minutes.rounded())
        if spoken { return m % 60 == 0 ? "\(m / 60) hours" : "\(m / 60) hours \(m % 60) minutes" }
        if dropZeroMinutes && m % 60 == 0 { return "\(m / 60)H" }
        return "\(m / 60)H \(String(format: "%02d", m % 60))M"
    }

    // MARK: The run

    @MainActor
    private func run() async {
        if reduce {
            fill = 1
            chipsShown = true
            itemsShown = things.count
            bubbleShown = true
            return
        }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = true }
        guard await printPause(0.4) else { return }
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 1.4)) { fill = 1 }
        guard await printPause(1.2) else { return }
        chipsShown = true
        landed += 1
        guard await printPause(0.9) else { return }
        for i in 0..<things.count {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { itemsShown = i + 1 }
            landed += 1
            guard await printPause(0.3) else { return }
        }
        guard await printPause(0.4) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) { bubbleShown = true }
    }
}

// MARK: - Speech bubble

/// The brain's line, with a small tail pointing up at it.
private struct Bubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(PrintFont.hand(21))
            .foregroundStyle(Ink.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 18,
                                               topTrailingRadius: 4, style: .continuous).fill(Color.white)
                .shadow(color: Ink.ink.opacity(0.14), radius: 9, y: 6))
            .overlay(alignment: .topTrailing) {
                Tail().fill(Color.white).frame(width: 16, height: 11).offset(x: -46, y: -10)
            }
    }

    private struct Tail: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.closeSubpath()
            return p
        }
    }
}
