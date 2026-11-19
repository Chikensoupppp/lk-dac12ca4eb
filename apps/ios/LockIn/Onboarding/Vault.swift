import SwiftUI

/// Slide 3's vault (mock: docs/design/vault-flow.html). Tapping spins the dial through a
/// combination while iPhone's Screen Time box comes up; once access is on, the wheel turns, the
/// bolts slide back, the door clunks ajar with light leaking out and swings wide while sun rays
/// fan out behind and the "?H ??M" card floats up. The number itself is the next slide.
/// Every moving part reads one clock, so nothing waits on SwiftUI animation timing.
struct Vault: View {
    /// When the dial started its combination; nil while idle.
    var dialAt: Date?
    /// When the opening started; nil while shut.
    var openAt: Date?
    var reduceMotion: Bool
    var tap: () -> Void

    /// Seconds from `openAt` until the door is fully open and the card has landed.
    static let openDuration = 2.4

    private static let width: CGFloat = 290
    private static let height: CGFloat = 236
    private static let inset: CGFloat = 14

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || (dialAt == nil && openAt == nil))) { timeline in
            let s = state(at: timeline.date)
            ZStack {
                rays(s, timeline.date)
                safe(s)
                    .offset(x: 3 * s.shake)
                    .scaleEffect(s.push)
                sparkles(s)
            }
            .frame(width: Self.width, height: Self.height + 10)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: tap)
        .accessibilityElement()
        .accessibilityLabel(openAt == nil ? "A locked vault" : "The vault is open")
        .accessibilityAddTraits(openAt == nil ? .isButton : [])
        .accessibilityAction(.default, tap)
    }

    // MARK: Clock

    struct State {
        var dial = 0.0, wheel = 0.0, bolts = 0.0, door = 0.0, shake = 0.0, push = 1.0
        var leak = 0.0, rays = 0.0, card = 0.0, sparkle = -1.0
    }

    private func state(at now: Date) -> State {
        var s = State()
        if let dialAt {
            let x = reduceMotion ? 9 : now.timeIntervalSince(dialAt)
            // Right, left, right; a jolt at each stop.
            s.dial = 300 * eio(seg(x, 0, 0.45)) - 200 * eio(seg(x, 0.5, 0.85)) + 80 * eio(seg(x, 0.9, 1.15))
            s.shake = [0.45, 0.85, 1.15].reduce(0) { $0 + jolt(x - $1) * 0.6 }
        }
        if let openAt {
            let o = reduceMotion ? 9 : now.timeIntervalSince(openAt)
            s.wheel = 300 * eio(seg(o, 0, 0.6))
            s.bolts = eo(seg(o, 0.5, 0.75))
            let ajar = -7 * spring(seg(o, 0.8, 1.2))
            s.door = ajar + (-104 - ajar) * drawer(seg(o, 1.25, 2.2))
            s.shake += jolt(o - 0.8) * 1.2
            s.leak = seg(o, 0.8, 0.95) * (1 - seg(o, 1.4, 1.8))
            s.push = 1 + 0.06 * eio(seg(o, 0.8, 1.8)) - 0.03 * eio(seg(o, 1.8, 2.6))
            s.rays = eo(seg(o, 1.25, 2.0))
            s.card = spring(seg(o, 1.6, 2.3))
            s.sparkle = o - 1.7
        }
        return s
    }

    // MARK: Safe

    private func safe(_ s: State) -> some View {
        let frame = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return ZStack {
            frame.fill(LinearGradient(colors: [Color(hex: 0x3D62B4), Color(hex: 0x2B4C99)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(frame.strokeBorder(Ink.ink, lineWidth: 3))
                .background(frame.fill(Ink.ink).offset(y: 7))
            interior(s)
                .clipShape(inner)
                .overlay(inner.strokeBorder(Ink.ink, lineWidth: 3))
                .padding(Self.inset)
            // Light through the gap while the door sits ajar.
            Capsule()
                .fill(Color(hex: 0xFFE9A8))
                .frame(width: 6)
                .padding(.vertical, 18)
                .shadow(color: Color(hex: 0xFFC83C).opacity(0.9), radius: 10)
                .scaleEffect(x: 1, y: 0.6 + 0.4 * s.leak)
                .opacity(s.leak)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, Self.inset + 2)
            door(s)
                .padding(Self.inset)
            VStack {
                hinge; Spacer(); hinge
            }
            .padding(.vertical, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(x: -9)
        }
        .frame(width: Self.width, height: Self.height)
        .overlay(alignment: .bottom) {
            HStack { foot; Spacer(); foot }.padding(.horizontal, 28).offset(y: 16)
        }
    }

    private var hinge: some View { RoundedRectangle(cornerRadius: 3).fill(Ink.ink).frame(width: 11, height: 34) }
    private var foot: some View { UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4).fill(Ink.ink).frame(width: 34, height: 10) }

    private func interior(_ s: State) -> some View {
        ZStack {
            Ink.navy
            RadialGradient(colors: [Ink.sun.opacity(0.75), Ink.sun.opacity(0.12), .clear], center: UnitPoint(x: 0.5, y: 0.45), startRadius: 0, endRadius: 140)
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("YOUR TIME A DAY")
                        .font(PrintFont.mono(9.5, .bold))
                        .tracking(1.2)
                        .foregroundStyle(Ink.soft)
                    Text("?H ??M")
                        .font(PrintFont.head(44))
                        .foregroundStyle(Ink.blue)
                }
                .frame(width: 170)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12).fill(Ink.receipt))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.ink, lineWidth: 2))
                .shadow(color: Color(hex: 0xFFD66B).opacity(0.95), radius: 16)
                .offset(y: 16 * (1 - s.card))
                .scaleEffect(0.9 + 0.1 * s.card)
                .padding(.top, 30)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 6) {
                    goldStack(2); Spacer(); goldStack(1); goldStack(1)
                }
                .padding(.horizontal, 26)
                Rectangle().fill(Ink.ink).frame(height: 6).padding(.bottom, 28)
            }
        }
    }

    private func goldStack(_ n: Int) -> some View {
        VStack(spacing: -2) {
            if n > 1 { GoldBar() }
            HStack(spacing: 4) { GoldBar(); if n > 1 { GoldBar() } }
        }
    }

    // MARK: Door

    private func door(_ s: State) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let showBack = s.door < -90
        return ZStack {
            if showBack {
                shape.fill(Color(hex: 0x20396F)).overlay(shape.strokeBorder(Ink.ink, lineWidth: 3))
            } else {
                ZStack(alignment: .topLeading) {
                    shape.fill(LinearGradient(colors: [Color(hex: 0x5079CF), Ink.blue, Color(hex: 0x2A4A92)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Ink.ink.opacity(0.35), lineWidth: 2).padding(10)
                    rivets
                    dial(s.dial).offset(x: 20, y: 44)
                    wheel(s.wheel).offset(x: 134, y: 52)
                    ForEach([28.0, 90.0, 152.0], id: \.self) { y in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [Color(hex: 0xE5E8EE), Color(hex: 0xA9AFBC)], startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Ink.ink, lineWidth: 2))
                            .frame(width: 30, height: 14)
                            .offset(x: 236 - 22 * s.bolts, y: y)
                    }
                }
                .overlay(shape.strokeBorder(Ink.ink, lineWidth: 3))
            }
        }
        .rotation3DEffect(.degrees(s.door), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.45)
    }

    private var rivets: some View {
        let w = Self.width - 2 * Self.inset, h = Self.height - 2 * Self.inset
        let spots: [CGPoint] = [CGPoint(x: 14, y: 14), CGPoint(x: w - 20, y: 14), CGPoint(x: 14, y: h - 20),
                                CGPoint(x: w - 20, y: h - 20), CGPoint(x: w / 2 - 3, y: 14), CGPoint(x: w / 2 - 3, y: h - 20)]
        return ForEach(0..<spots.count, id: \.self) { i in
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x9DB2E2), Ink.ink], center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: 5))
                .frame(width: 7, height: 7)
                .offset(x: spots[i].x, y: spots[i].y)
        }
    }

    private func dial(_ angle: Double) -> some View {
        ZStack {
            Circle().fill(Ink.receipt).overlay(Circle().strokeBorder(Ink.ink, lineWidth: 3))
            ForEach(0..<40, id: \.self) { i in
                Rectangle().fill(Ink.ink)
                    .frame(width: 2, height: i % 5 == 0 ? 12 : 6)
                    .offset(y: -50 + (i % 5 == 0 ? 6 : 3))
                    .rotationEffect(.degrees(Double(i) * 9))
            }
            KnobBall(size: 40)
            Capsule().fill(Ink.ink).frame(width: 4, height: 14).offset(y: -10)
        }
        .frame(width: 108, height: 108)
        .rotationEffect(.degrees(angle))
        .background(Circle().fill(Ink.ink.opacity(0.5)).offset(y: 4))
        .overlay(alignment: .top) {
            Triangle().fill(Ink.sun).frame(width: 14, height: 11).offset(y: -12).shadow(color: Ink.ink, radius: 0, y: 1)
        }
    }

    private func wheel(_ angle: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(Ink.ink).frame(width: 8, height: 92).rotationEffect(.degrees(Double(i) * 60))
            }
            ForEach(0..<6, id: \.self) { i in
                KnobBall(size: 16).offset(y: -44).rotationEffect(.degrees(Double(i) * 60))
            }
            KnobBall(size: 28)
        }
        .frame(width: 96, height: 96)
        .rotationEffect(.degrees(angle))
    }

    // MARK: Light

    private func rays(_ s: State, _ now: Date) -> some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2), r = max(size.width, size.height)
            var wedges = Path()
            for i in 0..<18 {
                let a = Double(i) * 20 * .pi / 180, b = a + 7 * .pi / 180
                wedges.move(to: c)
                wedges.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
                wedges.addLine(to: CGPoint(x: c.x + r * cos(b), y: c.y + r * sin(b)))
                wedges.closeSubpath()
            }
            context.fill(wedges, with: .color(Ink.sun.opacity(0.42)))
        }
        .frame(width: 560, height: 560)
        .mask(RadialGradient(colors: [.black, .black.opacity(0.6), .clear], center: .center, startRadius: 40, endRadius: 280))
        .rotationEffect(.degrees(reduceMotion ? 0 : now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 360) * 14))
        .scaleEffect(0.7 + 0.3 * s.rays)
        .opacity(s.rays)
        .allowsHitTesting(false)
    }

    private func sparkles(_ s: State) -> some View {
        let spots: [CGPoint] = [.init(x: -10, y: -10), .init(x: 290, y: -18), .init(x: -26, y: 150), .init(x: 300, y: 160),
                                .init(x: 40, y: -30), .init(x: 250, y: 250), .init(x: 20, y: 255), .init(x: 140, y: -40)]
        return ZStack(alignment: .topLeading) {
            ForEach(0..<spots.count, id: \.self) { i in
                let p = seg(s.sparkle - Double(i) * 0.09, 0, 0.6)
                let live = p > 0 && p < 1 && !reduceMotion
                Sparkle()
                    .fill(Ink.sun)
                    .frame(width: 16, height: 16)
                    .scaleEffect(0.4 + 0.9 * sin(.pi * p))
                    .rotationEffect(.degrees(p * 90))
                    .opacity(live ? sin(.pi * p) : 0)
                    .offset(x: spots[i].x, y: spots[i].y)
            }
        }
        .frame(width: Self.width, height: Self.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    // MARK: Curves (the strong ease-out / ease-in-out / drawer curves, as cubic-beziers)

    private func seg(_ t: Double, _ a: Double, _ b: Double) -> Double { min(1, max(0, (t - a) / (b - a))) }
    private func eo(_ x: Double) -> Double { Self.bezier(0.23, 1, 0.32, 1, x) }
    private func eio(_ x: Double) -> Double { Self.bezier(0.77, 0, 0.175, 1, x) }
    private func drawer(_ x: Double) -> Double { Self.bezier(0.32, 0.72, 0, 1, x) }
    /// About 0.2 bounce, 0 → 1.
    private func spring(_ p: Double) -> Double { p <= 0 ? 0 : p >= 1 ? 1 : 1 - exp(-6 * p) * cos(10 * p) }
    /// A short decaying wobble starting at 0.
    private func jolt(_ q: Double) -> Double { q > 0 && q < 0.35 ? exp(-12 * q) * sin(60 * q) : 0 }

    static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        let cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx
        let cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by
        var t = x
        for _ in 0..<8 {
            let e = ((ax * t + bx) * t + cx) * t - x
            let d = (3 * ax * t + 2 * bx) * t + cx
            if abs(e) < 1e-5 || d == 0 { break }
            t -= e / d
        }
        t = min(1, max(0, t))
        return ((ay * t + by) * t + cy) * t
    }
}

private struct KnobBall: View {
    let size: CGFloat
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xFFE08A), Ink.sun, Color(hex: 0xC98800)],
                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.6))
            .overlay(Circle().strokeBorder(Ink.ink, lineWidth: size > 20 ? 3 : 2))
            .frame(width: size, height: size)
    }
}

private struct GoldBar: View {
    var body: some View {
        Trapezoid()
            .fill(LinearGradient(colors: [Color(hex: 0xFFD66B), Color(hex: 0xE79E00)], startPoint: .top, endPoint: .bottom))
            .overlay(Trapezoid().stroke(Ink.ink, lineWidth: 2))
            .frame(width: 32, height: 13)
    }
}

private struct Trapezoid: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX + r.width * 0.14, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.14, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

/// A four-point twinkle.
private struct Sparkle: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY), w = r.width / 2, k = w * 0.24
        return Path { p in
            p.move(to: CGPoint(x: c.x, y: c.y - w))
            p.addLine(to: CGPoint(x: c.x + k, y: c.y - k))
            p.addLine(to: CGPoint(x: c.x + w, y: c.y))
            p.addLine(to: CGPoint(x: c.x + k, y: c.y + k))
            p.addLine(to: CGPoint(x: c.x, y: c.y + w))
            p.addLine(to: CGPoint(x: c.x - k, y: c.y + k))
            p.addLine(to: CGPoint(x: c.x - w, y: c.y))
            p.addLine(to: CGPoint(x: c.x - k, y: c.y - k))
            p.closeSubpath()
        }
    }
}
