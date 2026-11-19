import SwiftUI

/// Slide 3's slot machine (mock: docs/design/slot-flow.html). Pulling the lever spins the reels
/// while iPhone's Screen Time box is up; once it is answered the reels land, one by one, on "?":
/// the real number is the next slide. Everything moves off one clock, so the reels can keep
/// spinning for however long the person takes to answer.
struct SlotMachine: View {
    /// When the lever was pulled; nil while the machine idles.
    var pulledAt: Date?
    /// When the box was answered and the reels may land.
    var landAt: Date?
    /// Screen Time came back on: the bulbs flash and the "you're in" stamp lands.
    var won: Bool
    var reduceMotion: Bool
    var pull: () -> Void

    static let symbols = ["?", "4", "7", "2", "9", "5", "1", "8", "3", "6"]
    /// Reel speed in symbols a second, the time to reach it, and when the spin starts after the pull.
    static let speed = 28.0
    static let spinUp = 0.25
    static let leverTime = 0.35

    /// Seconds after the pull at which the last reel is still. The caller waits this long.
    static func settleTime(afterLand land: Double) -> Double { land + 0.95 + 0.28 * 2 + 0.2 }

    private static let cell: CGFloat = 84
    private var cell: CGFloat { Self.cell }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let now = timeline.date
            HStack(alignment: .top, spacing: 2) {
                cabinet(now)
                lever(now)
            }
        }
        .frame(height: 226)
    }

    // MARK: Clock

    private func sinceSpin(_ now: Date) -> Double? {
        guard let pulledAt, !reduceMotion else { return nil }
        return now.timeIntervalSince(pulledAt) - Self.leverTime
    }

    private var land: Double? {
        guard let pulledAt, let landAt else { return nil }
        return landAt.timeIntervalSince(pulledAt) - Self.leverTime
    }

    /// Where reel `i` is (in symbols) and how fast it moves. Free spin speeds up over `spinUp`;
    /// landing picks a stop on "?" that a straight slow-down reaches with no jump in speed,
    /// finishing 0.28 s after the reel to its left, then a small settle wobble.
    private func reel(_ i: Int, _ s: Double) -> (pos: Double, vel: Double) {
        let v = Self.speed, up = Self.spinUp
        func free(_ x: Double) -> Double { x <= 0 ? 0 : x < up ? v * x * x / (2 * up) : v * (x - up / 2) }
        func vel(_ x: Double) -> Double { x <= 0 ? 0 : x < up ? v * x / up : v }
        guard let land, land > up else { return (free(s), vel(s)) }
        let finish = land + 0.95 + 0.28 * Double(i)
        let target = (v / 2 * (land + finish - up) / 10).rounded(.up) * 10
        let start = 2 * target / v - finish + up
        if s < start { return (free(s), vel(s)) }
        if s >= finish {
            let w = s - finish
            return (target + (w < 0.5 ? 0.08 * exp(-9 * w) * sin(22 * w) : 0), 0)
        }
        let dl = finish - start, q = (s - start) / dl, p0 = free(start)
        return (p0 + (target - p0) * (1 - (1 - q) * (1 - q)), 2 * (target - p0) * (1 - q) / dl)
    }

    // MARK: Cabinet

    private func cabinet(_ now: Date) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let s = sinceSpin(now)
        return VStack(spacing: 0) {
            marquee(now, s)
            HStack(spacing: 3) {
                reelView(0, s)
                unit("H")
                reelView(1, s)
                reelView(2, s)
                unit("M")
            }
            .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Ink.receipt))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Ink.ink, lineWidth: 3))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Hours a day: unknown")
            Text("ONLY ON YOUR IPHONE")
                .font(PrintFont.mono(10, .bold))
                .tracking(1.2)
                .foregroundStyle(Color(hex: 0xF7DCD4))
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0x8E3424)))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Ink.ink, lineWidth: 2))
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
        }
        .background(shape.fill(Ink.red))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 3))
        .background(shape.fill(Ink.ink).offset(y: 6))
        .overlay(alignment: .bottomTrailing) { stamp(now) }
        .frame(maxWidth: .infinity)
    }

    private func marquee(_ now: Date, _ s: Double?) -> some View {
        let t = now.timeIntervalSinceReferenceDate
        let spinning = s.map { $0 > 0 && landAt == nil } ?? false
        let flashing = won && (s.map { secondsAfterSettle($0) < 1.4 } ?? false)
        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<13, id: \.self) { i in
                    let on = reduceMotion ? i % 3 == 0
                        : flashing ? Int(t * 7) % 2 == 0
                        : (Int(t * (spinning ? 18 : 9)) + i) % 4 == 0
                    Circle()
                        .fill(on ? Color(hex: 0xFFD66B) : Color(hex: 0x5A4416))
                        .frame(width: 9, height: 9)
                        .shadow(color: on ? Ink.sun : .clear, radius: 4)
                        .frame(maxWidth: .infinity)
                }
            }
            Text("HOURS A DAY")
                .font(PrintFont.head(21))
                .tracking(2)
                .foregroundStyle(Ink.sun)
        }
        .padding(.horizontal, 8)
        .padding(.top, 9)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .top)
        .background(Ink.ink)
        .accessibilityHidden(true)
    }

    private func secondsAfterSettle(_ s: Double) -> Double {
        guard let land else { return -1 }
        return s - (land + 0.95 + 0.56)
    }

    private func reelView(_ i: Int, _ s: Double?) -> some View {
        let (pos, vel) = s.map { reel(i, $0) } ?? (0, 0)
        let wrapped = (pos.truncatingRemainder(dividingBy: 10) + 10).truncatingRemainder(dividingBy: 10)
        return VStack(spacing: 0) {
            ForEach(0..<20, id: \.self) { k in
                let sym = Self.symbols[k % 10]
                Text(sym)
                    .font(PrintFont.head(62))
                    .foregroundStyle(sym == "?" ? Ink.blue : Ink.ink)
                    .frame(height: cell)
            }
        }
        .offset(y: -CGFloat(wrapped) * cell + (100 - 6 - cell) / 2)
        .blur(radius: min(4, vel * 0.1))
        .frame(width: 52, height: 94, alignment: .top)
        .clipped()
        .overlay {
            LinearGradient(stops: [.init(color: .black.opacity(0.28), location: 0), .init(color: .clear, location: 0.32),
                                   .init(color: .clear, location: 0.68), .init(color: .black.opacity(0.28), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .background(Ink.receipt)
    }

    private func unit(_ text: String) -> some View {
        Text(text).font(PrintFont.head(30)).foregroundStyle(Ink.ink).frame(width: 22)
    }

    @ViewBuilder
    private func stamp(_ now: Date) -> some View {
        if won {
            let after = sinceSpin(now).map { secondsAfterSettle($0) } ?? 1
            let p = reduceMotion ? 1 : springValue(max(0, min(1, after / 0.6)))
            Stamp(text: "You\u{2019}re in", color: Ink.blue, size: 22, tilt: -10)
                .scaleEffect(1.25 - 0.25 * p)
                .opacity(after > 0 ? 1 : 0)
                .offset(x: 6, y: -18)
        }
    }

    // MARK: Lever

    private func lever(_ now: Date) -> some View {
        // Pulled toward the viewer: the stick foreshortens and the ball swings down past the mount.
        let x = pulledAt.map { now.timeIntervalSince($0) } ?? -1
        let down = easeInOut(max(0, min(1, x / Self.leverTime)))
        let back = springValue(max(0, min(1, (x - Self.leverTime) / 0.7)))
        let th = reduceMotion ? 0 : 150 * down * (1 - back) * .pi / 180
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8).fill(Ink.ink)
                .frame(width: 14, height: 46)
                .offset(x: -2, y: 112)
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0x555555), Ink.ink], startPoint: .leading, endPoint: .trailing))
                .frame(width: 8, height: 112)
                .scaleEffect(x: 1, y: cos(th), anchor: .bottom)
                .offset(x: 10, y: 18)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFE08A), Ink.sun, Color(hex: 0xC98800)],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 20))
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 3))
                .frame(width: 32, height: 32)
                .scaleEffect(1 + 0.25 * sin(th))
                .offset(x: -2, y: 112 * (1 - cos(th)))
        }
        .frame(width: 30, height: 226, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture(perform: pull)
        .gesture(DragGesture(minimumDistance: 12).onEnded { if $0.translation.height > 30 { pull() } })
        .accessibilityElement()
        .accessibilityLabel("Lever")
        .accessibilityHint("Spins the reels and opens the Screen Time box")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, pull)
    }

    private func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
    /// A spring with a little bounce (about 0.2), 0 → 1.
    private func springValue(_ p: Double) -> Double { p <= 0 ? 0 : p >= 1 ? 1 : 1 - exp(-6 * p) * cos(10 * p) }
}
