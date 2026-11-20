import SwiftUI

/// Onboarding slide 5, shared by the app and the LockInReport extension. The extension draws it with
/// the user's real Screen Time (the app is never allowed to read that number); the app draws it from
/// the guess when there is no report. One bar is the awake day (16 hours), the blue part the phone,
/// with the share, the time left, an hour scale and week / month / year totals, then what that much
/// time is enough for every day. The brain reacts. Mock: docs/design/day-bar-v2.html.
/// Self-contained on purpose: the extension cannot use the app's code.
struct DayBarSlide: View {
    /// Hours a day on the phone.
    let hours: Double
    /// The big headline, e.g. "5H 12M\nA DAY." for real data or "5–6 hours\na day." for a guess.
    let headline: String
    /// False inside the report extension: Apple's report view stops animating partway, so it is
    /// drawn finished there.
    var animated = true
    /// The app's cover while Apple's report draws the real slide: same layout, but every number
    /// spins and the brain does sums, so no made-up number is ever shown. The report replaces it.
    var computing = false

    @Environment(\.accessibilityReduceMotion) private var reduce

    @State private var fill: Double = 0
    @State private var chipsShown = false
    @State private var itemsShown = 0
    @State private var bubbleShown = false
    @State private var landed = 0
    @State private var bob = false

    private static let awake: Double = 16
    static let paper = Color(red: 0.906, green: 0.910, blue: 0.890)
    private static let ink = Color(red: 0.106, green: 0.106, blue: 0.106)
    private static let blue = Color(red: 0.196, green: 0.333, blue: 0.643)
    private static let sun = Color(red: 1, green: 0.710, blue: 0.067)
    private static let red = Color(red: 0.898, green: 0.282, blue: 0.302)
    private static let cardFill = Color(red: 0.957, green: 0.957, blue: 0.941)

    private var band: Int { hours < 2.5 ? 0 : hours < 4.5 ? 1 : hours < 6.5 ? 2 : 3 }

    private static let lines = [
        "A little more intentional time can go a long way.",
        "What would you do with a little of that time back?",
        "That\u{2019}s a lot of time. How much of it is really yours to choose?",
        "You don\u{2019}t have to change everything today. Start with 25 minutes."
    ]
    private static let says = ["Nice! Most of the day is still yours.", "Hmm. Want some of it back?",
                               "A third of your day? Oof.", "Half your day?! Let\u{2019}s fix this."]

    var body: some View {
        if computing {
            TimelineView(.animation(paused: reduce)) { timeline in
                computingSlide(timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            finished
        }
    }

    private var finished: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Text(headline.uppercased())
                    .font(.system(size: 46, weight: .black).width(.compressed))
                    .foregroundStyle(Self.ink)
                    .lineSpacing(-4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                brain
            }
            ZStack(alignment: .topLeading) {
                Text(Self.lines[band])
                    .font(.system(size: 17, weight: .heavy).width(.condensed))
                    .foregroundStyle(Self.ink.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(bubbleShown ? 0 : 1)
                if bubbleShown {
                    Bubble(text: Self.says[band], ink: Self.ink)
                        .transition(.scale(scale: 0.7, anchor: .topTrailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, -10)
            card
            enough
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .sensoryFeedback(.impact(weight: .light), trigger: landed)
        .task { await run() }
    }

    // MARK: Doing the math (the app's cover)

    /// A digit that changes 14 times a second, or "?" with Reduce Motion.
    private func spin(_ t: Double, _ slot: Int, below limit: Int = 10) -> String {
        if reduce { return "?" }
        var x = UInt64(truncatingIfNeeded: Int(t * 14) &* 7919 &+ slot &* 104_729)
        x ^= x >> 13; x &*= 0x5bd1_e995; x ^= x >> 15
        return String(x % UInt64(limit))
    }

    private func computingSlide(_ t: Double) -> some View {
        let soft = Self.ink.opacity(0.6)
        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Text(headline.uppercased())
                    .font(.system(size: 46, weight: .black).width(.compressed))
                    .foregroundStyle(Self.ink)
                    .lineSpacing(-4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image("BrainExact")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104)
                    .offset(y: reduce ? 0 : -3 * sin(t * 4.2))
                    .rotationEffect(.degrees(reduce ? 0 : 4 * sin(t * 2.1)))
                    .overlay(alignment: .top) { sums(t) }
            }
            Text("Your hours, your week, your year. Adding it all up.")
                .font(.system(size: 17, weight: .heavy).width(.condensed))
                .foregroundStyle(Self.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, -10)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(spin(t, 0, below: 13))H \(spin(t, 1, below: 6))\(spin(t, 2))M")
                    .font(.system(size: 56, weight: .black).width(.compressed))
                    .monospacedDigit()
                    .foregroundStyle(Self.ink)
                Text("ON YOUR PHONE, OUT OF 16 HOURS AWAKE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2)
                    .foregroundStyle(soft)
                    .padding(.top, 4)
                sweepBar(t)
                    .frame(height: 36)
                    .padding(.top, 14)
                HStack {
                    ForEach(["0H", "4H", "8H", "12H", "16H"], id: \.self) { l in
                        Text(l).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(Self.ink.opacity(0.55))
                        if l != "16H" { Spacer() }
                    }
                }
                .padding(.top, 5)
                HStack(spacing: 8) {
                    spinChip("EVERY WEEK", "\(spin(t, 3, below: 9))\(spin(t, 4))H \(spin(t, 5, below: 6))\(spin(t, 6))M")
                    spinChip("A MONTH, NONSTOP", "\(spin(t, 7))\(spin(t, 8)) DAYS")
                    spinChip("A YEAR, NONSTOP", "\(spin(t, 9, below: 3))\(spin(t, 10))\(spin(t, 11)) DAYS")
                }
                .padding(.top, 12)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Self.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Self.ink, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Self.ink).offset(y: 5))
            VStack(alignment: .leading, spacing: 10) {
                Text("EVERY DAY, THAT\u{2019}S ENOUGH TIME FOR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.6)
                    .foregroundStyle(soft)
                spinRow(t, 0, "tv.fill", Self.red, .white, "\(spin(t, 12))\(spin(t, 13))", "episodes of a show")
                spinRow(t, 1, "book.fill", Self.sun, Self.ink, "\(spin(t, 14))\(spin(t, 15))\(spin(t, 16))", "pages of a book")
                spinRow(t, 2, "dumbbell.fill", Self.blue, .white, spin(t, 17), "gym sessions")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adding up your day")
    }

    /// Math signs floating up off the brain.
    private func sums(_ t: Double) -> some View {
        let signs: [(String, Color)] = [("+", Self.blue), ("\u{00D7}", Self.red), ("\u{00F7}", Self.blue),
                                        ("=", Color(red: 0.79, green: 0.53, blue: 0)), ("%", Self.blue)]
        return ZStack(alignment: .topLeading) {
            ForEach(0..<signs.count, id: \.self) { i in
                let p = ((t + Double(i) * 0.37).truncatingRemainder(dividingBy: 1.6)) / 1.6
                Text(signs[i].0)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(signs[i].1)
                    .scaleEffect(0.8 + 0.4 * p)
                    .opacity(reduce ? 0 : sin(.pi * p) * 0.9)
                    .offset(x: Double(i) * 18 + 6 * sin(p * 6 + Double(i)), y: 10 - 60 * p)
            }
        }
        .frame(width: 104, alignment: .leading)
        .allowsHitTesting(false)
    }

    /// The day bar while the sums run: a striped segment sweeps back and forth.
    private func sweepBar(_ t: Double) -> some View {
        GeometryReader { g in
            let w = g.size.width
            let ph = (t * 0.9).truncatingRemainder(dividingBy: 2)
            let x = ph < 1 ? Self.easeInOut(ph) : 1 - Self.easeInOut(ph - 1)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white)
                Canvas { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.blue))
                    var stripes = Path()
                    var s: CGFloat = -size.height
                    while s < size.width {
                        stripes.move(to: CGPoint(x: s, y: size.height)); stripes.addLine(to: CGPoint(x: s + size.height, y: 0))
                        s += 16
                    }
                    context.stroke(stripes, with: .color(.white.opacity(0.18)), lineWidth: 7)
                }
                .frame(width: w * 0.34)
                .overlay(Rectangle().strokeBorder(Self.ink, lineWidth: 2))
                .offset(x: reduce ? 0 : w * 0.66 * CGFloat(x))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Self.ink, lineWidth: 2))
        }
    }

    private func spinChip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.1)
                .foregroundStyle(Self.ink.opacity(0.6))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.system(size: 22, weight: .black).width(.compressed)).monospacedDigit().foregroundStyle(Self.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Self.ink.opacity(0.14), lineWidth: 1.5))
    }

    private func spinRow(_ t: Double, _ i: Int, _ symbol: String, _ fill: Color, _ glyph: Color, _ n: String, _ label: String) -> some View {
        let ph = (t * 1.2 - Double(i) * 0.33).truncatingRemainder(dividingBy: 1.2)
        let hop = ph >= 0 && ph < 0.5 ? sin(.pi * ph / 0.5) : 0
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(glyph)
                .frame(width: 38, height: 38)
                .background(Circle().fill(fill))
                .overlay(Circle().strokeBorder(Self.ink, lineWidth: 2))
                .background(Circle().fill(Self.ink).offset(y: 3))
                .offset(y: reduce ? 0 : -6 * hop)
            Text(n)
                .font(.system(size: 28, weight: .black).width(.compressed))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 16, weight: .heavy).width(.condensed))
        }
        .foregroundStyle(Self.ink)
    }

    private static func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }

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
        let share = min(hours / Self.awake, 1)
        let left = max(Self.awake * 60 - minutes, 0)
        let soft = Self.ink.opacity(0.6)
        return VStack(alignment: .leading, spacing: 0) {
            Text(Self.hm(minutes))
                .font(.system(size: 56, weight: .black).width(.compressed))
                .monospacedDigit()
                .foregroundStyle(Self.ink)
                .contentTransition(.numericText(value: minutes))
            Text("ON YOUR PHONE, OUT OF 16 HOURS AWAKE")
                .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2)
                .foregroundStyle(soft)
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
                    .stroke(Self.ink.opacity(0.12), lineWidth: 2)
                    Rectangle()
                        .fill(Self.blue)
                        .frame(width: max(0, w * CGFloat(share * fill)))
                        .overlay(alignment: .trailing) { Rectangle().fill(Self.ink).frame(width: fill > 0 ? 2 : 0) }
                    Text("\(Int((share * fill * 100).rounded()))%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.leading, 10)
                        .opacity(fill > 0.05 && share > 0.06 ? 1 : 0)
                    HStack {
                        Spacer()
                        Text("\(Self.hm(left)) LEFT FOR YOU")
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
                            .foregroundStyle(soft)
                            .padding(.horizontal, 4).padding(.vertical, 3)
                            .background(Color.white)
                            .padding(.trailing, 8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Self.ink, lineWidth: 2))
            }
            .frame(height: 36)
            .padding(.top, 14)

            HStack {
                ForEach(["0H", "4H", "8H", "12H", "16H"], id: \.self) { l in
                    Text(l).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(Self.ink.opacity(0.55))
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
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Self.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Self.ink, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Self.ink).offset(y: 5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.hm(hours * 60, spoken: true)) a day on your phone, \(Int((share * 100).rounded())) percent of 16 hours awake. Every week \(Self.hm(hours * 7 * 60, spoken: true)). In a year, \(Int((hours * 365 / 24).rounded())) full days.")
    }

    private func chip(_ label: String, _ value: String, _ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.1)
                .foregroundStyle(Self.ink.opacity(0.6))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.system(size: 22, weight: .black).width(.compressed)).foregroundStyle(Self.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Self.ink.opacity(0.14), lineWidth: 1.5))
        .opacity(chipsShown ? 1 : 0)
        .offset(y: chipsShown ? 0 : 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(i) * 0.08), value: chipsShown)
    }

    // MARK: What the time is enough for

    /// 45-minute episodes, about 40 pages an hour, 1-hour workouts. Round stickers, never app icons.
    private var things: [(n: Int, one: String, many: String, symbol: String, fill: Color, glyph: Color)] {
        let all: [(n: Int, one: String, many: String, symbol: String, fill: Color, glyph: Color)] = [
            (Int(hours * 60 / 45), "episode of a show", "episodes of a show", "tv.fill", Self.red, .white),
            (Int((hours * 40 / 10).rounded()) * 10, "page of a book", "pages of a book", "book.fill", Self.sun, Self.ink),
            (Int(hours), "gym session", "gym sessions", "dumbbell.fill", Self.blue, .white)
        ]
        return all.filter { $0.n > 0 }
    }

    private var enough: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EVERY DAY, THAT\u{2019}S ENOUGH TIME FOR")
                .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.6)
                .foregroundStyle(Self.ink.opacity(0.6))
            ForEach(Array(things.enumerated()), id: \.offset) { i, t in
                let on = i < itemsShown
                HStack(spacing: 12) {
                    Image(systemName: t.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(t.glyph)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(t.fill))
                        .overlay(Circle().strokeBorder(Self.ink, lineWidth: 2))
                        .background(Circle().fill(Self.ink).offset(y: 3))
                        .scaleEffect(on ? 1 : 0.6)
                        .rotationEffect(.degrees(on ? 0 : (i % 2 == 0 ? -5 : 5)))
                    Text("\(on ? t.n : 0)")
                        .font(.system(size: 28, weight: .black).width(.compressed))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(on ? t.n : 0)))
                    Text(t.n == 1 ? t.one : t.many)
                        .font(.system(size: 16, weight: .heavy).width(.condensed))
                }
                .foregroundStyle(Self.ink)
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
        if reduce || !animated {
            fill = 1
            chipsShown = true
            itemsShown = things.count
            bubbleShown = true
            return
        }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = true }
        guard await pause(0.4) else { return }
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 1.4)) { fill = 1 }
        guard await pause(1.2) else { return }
        chipsShown = true
        landed += 1
        guard await pause(0.9) else { return }
        for i in 0..<things.count {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { itemsShown = i + 1 }
            landed += 1
            guard await pause(0.3) else { return }
        }
        guard await pause(0.4) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) { bubbleShown = true }
    }

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }
}

// MARK: - Speech bubble

/// The brain's line, with a small tail pointing up at it.
private struct Bubble: View {
    let text: String
    let ink: Color

    var body: some View {
        Text(text)
            .font(.custom("MarkerFelt-Wide", fixedSize: 21))
            .foregroundStyle(ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 18,
                                               topTrailingRadius: 4, style: .continuous).fill(Color.white)
                .shadow(color: ink.opacity(0.14), radius: 9, y: 6))
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

// MARK: - Fit

/// Shrinks its content evenly when it is taller than `height`, so slide 5 keeps its look and still
/// ends above the button on every iPhone. Used by the app and by the report extension.
struct ScaleToFitHeight: ViewModifier {
    let height: CGFloat
    @State private var natural: CGFloat = 0

    func body(content: Content) -> some View {
        let scale = natural > height && height > 0 ? height / natural : 1
        content
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { natural = g.size.height }
                    .onChange(of: g.size.height) { _, h in natural = h }
            })
            .scaleEffect(scale, anchor: .top)
            .frame(height: natural > 0 ? min(natural, height) : nil, alignment: .top)
    }
}

extension View {
    func scaleToFit(height: CGFloat) -> some View { modifier(ScaleToFitHeight(height: height)) }
}
