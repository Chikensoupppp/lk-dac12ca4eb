import SwiftUI

/// Slide 5: what your hours mean for one day. The waking day is 16 hour tiles; the phone hours flip
/// blue one by one, each stamped with an app, while the count climbs. Then the share of the day, the
/// brain's reaction and one "you are here" finding. Mock: docs/design/waking-day-v1.html.
/// (The file keeps its old name; the heart monitor is gone.)
struct HeartBrainStep: View {
    let hoursIndex: Int
    let next: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduce: Bool { effectiveReduceMotion(systemReduceMotion) }

    @State private var shown = 0
    @State private var shareShown = false
    @State private var bubbleShown = false
    @State private var findShown = false
    @State private var bob = false

    private var band: Int { min(max(hoursIndex, 0), 3) }
    private var hours: Double { [1.5, 3.5, 5.5, 7.5][band] }
    private var tileCount: Int { Int(hours.rounded(.up)) }
    private var hasHalf: Bool { hours.truncatingRemainder(dividingBy: 1) > 0 }

    private static let titles = ["1\u{2013}2 hours\na day.", "3\u{2013}4 hours\na day.", "5\u{2013}6 hours\na day.", "7+ hours\na day."]
    private static let lines = [
        "A little more intentional time can go a long way.",
        "What would you do with a little of that time back?",
        "That\u{2019}s a lot of time. How much of it is really yours to choose?",
        "You don\u{2019}t have to change everything today. Start with 25 minutes."
    ]
    private static let says = ["Nice! Most of the day is still ours.", "Hmm. Can we get some back?",
                               "A third of our day? Oof.", "Half our day?! Let\u{2019}s fix this."]
    /// (before, highlighted, after)
    private static let shares: [(String, String, String)] = [
        ("That\u{2019}s about ", "1 in every 10", " waking hours."), ("That\u{2019}s about ", "1 in every 5", " waking hours."),
        ("That\u{2019}s about ", "1 in every 3", " waking hours."), ("That\u{2019}s ", "almost half", " of your waking hours.")
    ]
    /// Which hours (0 = 7 AM ... 15 = 10 PM) the phone takes, spread through the day like real use.
    private static let order = [13, 1, 9, 14, 5, 11, 15, 7, 3, 12]
    private static let glyphs = ["play.fill", "bubble.left.fill", "music.note", "envelope.fill",
                                 "heart.fill", "camera.fill", "gamecontroller.fill", "cart.fill"]

    var body: some View {
        PrintScaffold(step: 5, title: Self.titles[band], titleSize: 46, grain: true,
                      primaryTitle: "CONTINUE", primaryAction: next) {
            VStack(alignment: .leading, spacing: 22) {
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
                if findShown {
                    FindingCard(band: band)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: shown)
        .task { await run() }
    }

    // MARK: Pieces

    private var brain: some View {
        Image("BrainExact")
            .resizable()
            .scaledToFit()
            .frame(width: 104)
            .offset(y: bob ? -2 : 2)
            // A small hop each time a tile lands.
            .keyframeAnimator(initialValue: CGFloat(0), trigger: shown) { content, s in
                content.scaleEffect(x: 1 + s, y: 1 - s, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0.08, duration: 0.07)
                    SpringKeyframe(0, duration: 0.3, spring: .bouncy)
                }
            }
            // One wobble when it speaks.
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

    private var card: some View {
        let minutes = min(hours * 60, Double(shown) * 60 - (hasHalf && shown == tileCount ? 30 : 0))
        let m = Int(minutes)
        return VStack(alignment: .leading, spacing: 0) {
            Text("YOUR WAKING DAY \u{00B7} 16 HOURS")
                .font(PrintFont.mono(10, .bold)).tracking(1.6)
                .foregroundStyle(Ink.ink.opacity(0.6))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(m / 60)H \(String(format: "%02d", m % 60))M")
                    .font(PrintFont.head(52))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: minutes))
                    .animation(.snappy, value: shown)
                Text("ON YOUR PHONE").font(PrintFont.mono(12, .bold)).tracking(1.2)
            }
            .foregroundStyle(Ink.ink)
            .padding(.top, 6)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 8), spacing: 7) {
                ForEach(0..<16, id: \.self) { hour in tile(hour) }
            }
            .padding(.top, 12)
            share
                .padding(.top, 14)
                .opacity(shareShown ? 1 : 0)
                .offset(y: shareShown ? 0 : 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: 0xF4F4F0)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Ink.ink, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Ink.ink).offset(y: 5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("About \(Self.titles[band].replacingOccurrences(of: "\n", with: " ")) on your phone. \(shareSentence).")
    }

    private func tile(_ hour: Int) -> some View {
        let k = Self.order.firstIndex(of: hour).flatMap { $0 < tileCount ? $0 : nil }
        let filled = k.map { $0 < shown } ?? false
        let half = k == tileCount - 1 && hasHalf
        let h = 7 + hour
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Ink.ink.opacity(0.16), lineWidth: 2)
            Text("\((h + 11) % 12 + 1)\(h < 12 ? "a" : "p")")
                .font(PrintFont.mono(9, .semibold))
                .foregroundStyle(Ink.ink.opacity(0.4))
            if filled, let k {
                Image(systemName: Self.glyphs[k % Self.glyphs.count])
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.blue))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Ink.ink, lineWidth: 2))
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.ink).offset(y: 3))
                    .mask {
                        // A half hour fills the left half of its tile.
                        HStack(spacing: 0) {
                            Rectangle()
                            if half { Color.clear }
                        }
                        .padding(.bottom, -4)
                    }
                    .rotationEffect(.degrees(Double(k % 3 - 1) * 2.5))
                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity).combined(with: .offset(y: -14)),
                                            removal: .opacity))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var shareSentence: String {
        let s = Self.shares[band]
        return s.0 + s.1 + s.2
    }

    private var share: Text {
        let s = Self.shares[band]
        var mark = AttributedString(" \(s.1) ")
        mark.backgroundColor = Ink.sun
        return Text(s.0) + Text(mark) + Text(s.2)
    }

    // MARK: The run

    @MainActor
    private func run() async {
        if reduce {
            shown = tileCount
            shareShown = true
            bubbleShown = true
            findShown = true
            return
        }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = true }
        guard await printPause(0.5) else { return }
        for k in 0..<tileCount {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) { shown = k + 1 }
            guard await printPause(0.26) else { return }
        }
        guard await printPause(0.15) else { return }
        withAnimation(.easeOut(duration: 0.4)) { shareShown = true }
        guard await printPause(0.2) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) { bubbleShown = true }
        guard await printPause(0.75) else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { findShown = true }
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

// MARK: - Finding

/// One finding picked by hours, marked "you are here". Plain summaries, not quotes; sources in
/// docs/ONBOARDING_V2.md. All show links, not cause.
private struct FindingCard: View {
    let band: Int

    private static let notes: [(tag: String, text: String, source: String)] = [
        ("1\u{2013}2H", "In a study of 120,000 UK teens, about 1\u{2013}2 hours a day was not linked to lower well-being.",
         "Przybylski & Weinstein, Psychological Science, 2017"),
        ("3H+", "Teens on social media more than 3 hours a day were more likely to report anxiety or depression symptoms.",
         "Riehm et al., JAMA Psychiatry, 2019"),
        ("6H+", "In the same study, the link was stronger for teens on social media more than 6 hours a day.",
         "Riehm et al., JAMA Psychiatry, 2019"),
        ("7H+", "Teens with 7+ hours of daily screen time were about twice as likely to have been diagnosed with anxiety or depression.",
         "Twenge & Campbell, Preventive Medicine Reports, 2018")
    ]

    var body: some View {
        let note = Self.notes[band]
        VStack(alignment: .leading, spacing: 8) {
            Text("YOU ARE HERE \u{00B7} \(note.tag)")
                .font(PrintFont.mono(10, .bold)).tracking(1.4)
                .foregroundStyle(.white)
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(Capsule().fill(Ink.blue))
            Text(note.text)
                .font(PrintFont.bold(15))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(note.source). Links, not cause and effect. Not medical advice.")
                .font(PrintFont.mono(10, .medium))
                .foregroundStyle(Ink.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white)
            .shadow(color: Ink.ink.opacity(0.14), radius: 12, y: 8))
        .accessibilityElement(children: .combine)
    }
}
