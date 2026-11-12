import SwiftUI

/// The screen after the hours question (between steps 2 and 3, no number of its own).
/// A cartoon brain takes one hit per hour-block of phone time, and the more hours the user chose,
/// the worse it gets. A light day (1 to 2 hours) gets no hits: the brain is proud and the day is
/// drawn as 24 squares. It is a joke picture, not a health claim, and the sticker says so.
/// Nothing here names a real app or logo, and nothing claims a feature that is not built.
struct BrainStep: View {
    let hoursIndex: Int
    let next: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduce: Bool { effectiveReduceMotion(systemReduceMotion) }

    @State private var damage = 0
    @State private var proud = false
    @State private var squash: CGFloat = 0
    @State private var bubble: String?
    @State private var tileIndex: Int?
    @State private var tileGone = false
    /// Extra health lost on a light day, in sixths of the bar. Small, so the bar stays nearly full.
    @State private var barDip: CGFloat = 0
    @State private var pow: PowFx?
    @State private var powShown = false
    @State private var dayShown = 0
    @State private var finished = false

    private struct PowFx {
        var word: String
        var color: Color
        var x: CGFloat
        var rot: Double
    }

    // MARK: Content per answer

    private var index: Int { min(max(hoursIndex, 0), 3) }
    /// How many tiles hit the brain. The lightest answer gets none.
    private var hits: Int { [0, 3, 5, 6][index] }
    private var low: Bool { hits == 0 }

    private static let titles = ["1 to 2 hours a day.", "3 to 4 hours a day.", "5 to 6 hours a day.", "7+ hours a day."]
    private static let statusLines = [
        "Well done. Let\u{2019}s keep it like that.",
        "Your brain is getting tired.",
        "Your brain is begging.",
        "Your brain is gone."
    ]
    private static let more = ["just 1 more\u{2026}", "ok, 1 more\u{2026}", "12 more minutes\u{2026}", "1 more, then I stop\u{2026}"]
    private static let lowLines = ["ow! just a tiny one.", "ok, I can take that."]
    private static let plea = "no more brain rot plsss\u{2026}"

    /// What the brain says after hit `i`. The last hit is silent, and the fifth hit is the plea.
    private func line(afterHit i: Int) -> String? {
        if i == 4 { return Self.plea }
        if i < hits - 1, i < Self.more.count { return Self.more[i] }
        return nil
    }

    private static let tileStyles: [(symbol: String, color: UInt32)] = [
        ("play.fill", 0xE5484D), ("photo", 0xB24FD8), ("music.note", 0x2A2D33),
        ("bubble.left.fill", 0x3C8DF5), ("heart.fill", 0xFF4F8B), ("bell.fill", 0xF5A524)
    ]
    private static let tileX: [CGFloat] = [-94, 98, -14, 136, -68, 52]
    private static let powWords = ["BONK!", "ZAP!", "SPLAT!", "BZZT!", "WHAM!", "OOF!"]
    private static let powColors: [UInt32] = [0xFFD65A, 0xFF8FB1, 0x8FD3FF, 0xB6F08A, 0xFFB36B, 0xFF7B7B]
    private static let barColors: [UInt32] = [0x7BE0A0, 0xA8DC7A, 0xE3D36A, 0xF2B27A, 0xEE8A5E, 0xE5584D, 0xC23A3A]

    private var mood: BrainMood {
        if proud { return .proud }
        switch damage {
        case 0: return .happy
        case 1: return .worried
        case 2: return .dizzy
        case 3: return .droopy
        case 4, 5: return .crying
        default: return .dead
        }
    }

    // MARK: Body

    var body: some View {
        OBScaffold(step: 2, title: Self.titles[index], primaryTitle: "CONTINUE", primaryAction: next) {
            VStack(alignment: .leading, spacing: 14) {
                bar
                if low { dayStrip }
                scene
                if finished {
                    Text(Self.statusLines[index])
                        .font(Cream.rounded(22, .bold))
                        .foregroundStyle(OB.ice)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: finished)
        }
        .task { await run() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: damage)
    }

    private var bar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0x1B1D22))
                Capsule()
                    .fill(Color(hex: Self.barColors[damage]))
                    .frame(width: g.size.width * (CGFloat(6 - damage) - barDip) / 6)
            }
            .overlay(Capsule().strokeBorder(Matte.edge, lineWidth: 2))
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: CGFloat(damage) + barDip)
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }

    /// Space above the brain. The tile falls through it, so it is only kept when tiles fall.
    private var topGap: CGFloat { low ? 96 : 150 }

    private var scene: some View {
        ZStack(alignment: .top) {
            BrainView(damage: damage, mood: mood, squash: squash, reduce: reduce, proud: proud, size: 260)
                .padding(.top, topGap)

            if let tileIndex {
                let style = Self.tileStyles[tileIndex % Self.tileStyles.count]
                BrainFallingTile(symbol: style.symbol, color: Color(hex: style.color),
                                 x: Self.tileX[tileIndex % Self.tileX.count] * 0.6,
                                 spin: tileIndex % 2 == 0 ? 200 : -200,
                                 landY: topGap - 46, gone: tileGone)
                    .id(tileIndex)
                    .zIndex(3)
            }

            if let pow {
                BrainPowBurst(word: pow.word, color: pow.color)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(pow.rot))
                    .scaleEffect(powShown ? 1 : 0.2)
                    .opacity(powShown ? 1 : 0)
                    .offset(x: pow.x, y: topGap - 20)
            }

            if let bubble {
                BrainSpeechBubble(text: bubble)
                    .padding(.horizontal, 24)
                    .padding(.top, topGap + 227 + 14)
                    .transition(.scale(scale: 0.5, anchor: .top).combined(with: .opacity))
            }

            StickerNote(text: low && finished ? "well done" : "just for fun",
                        color: low && finished ? OB.sage : OB.warm, tilt: 4)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.top, 8)

            if low && finished { BrainSparkles(reduce: reduce) }
        }
        .frame(maxWidth: .infinity)
        .frame(height: topGap + 227 + 14 + 80)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A cartoon brain. \(finished ? Self.statusLines[index] : "")")
    }

    /// The day as 24 squares. Two are phone. The rest is the user's.
    private var dayStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                ForEach(0..<24, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(i < 2 ? OB.warm : OB.sage.opacity(0.22))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(i < 2 ? Color(hex: 0x2A1620) : OB.sage.opacity(0.55), lineWidth: 2))
                        .aspectRatio(1, contentMode: .fit)
                        .scaleEffect(i < dayShown ? 1 : 0.3)
                        .opacity(i < dayShown ? 1 : 0)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dayShown)
            if finished {
                Text("Up to 2 hours are phone. The rest is yours.")
                    .font(Cream.rounded(17, .bold))
                    .foregroundStyle(Matte.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A day of 24 squares. Up to 2 hours are phone. The rest is yours.")
    }

    // MARK: Animation

    private func pause(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return true
        } catch {
            return false
        }
    }

    /// The end state, with no motion. Used when motion is limited.
    private func settle() {
        damage = hits
        proud = low
        barDip = low ? 1 : 0
        dayShown = 24
        bubble = hits == 5 ? Self.plea : nil
        finished = true
    }

    @MainActor
    private func run() async {
        if reduce { settle(); return }
        if low { await runLow() } else { await runHits() }
    }

    @MainActor
    private func runLow() async {
        guard await pause(0.8) else { return }
        // One tile per hour. Each one bonks the head, then its square of the day fills.
        for i in 0..<2 {
            tileGone = false
            tileIndex = i
            guard await pause(0.7) else { return }
            squash = 1
            withAnimation(.spring(response: 0.45, dampingFraction: 0.4)) { squash = 0 }
            tileGone = true
            barDip += 0.5
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { dayShown = i + 1 }
            guard await pause(0.3) else { return }
            tileIndex = nil
            guard await pause(0.3) else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { bubble = Self.lowLines[i] }
            guard await pause(1.1) else { return }
            withAnimation(.easeOut(duration: 0.15)) { bubble = nil }
            guard await pause(0.3) else { return }
        }
        // The rest of the day is the user's.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { proud = true }
        squash = 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.4)) { squash = 0 }
        for k in 3...24 {
            dayShown = k
            guard await pause(0.09) else { return }
        }
        guard await pause(0.4) else { return }
        finished = true
    }

    @MainActor
    private func runHits() async {
        guard await pause(0.8) else { return }
        for i in 0..<hits {
            tileGone = false
            tileIndex = i
            guard await pause(0.7) else { return }

            withAnimation(.easeOut(duration: 0.15)) { bubble = nil }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { damage += 1 }
            squash = 1
            withAnimation(.spring(response: 0.45, dampingFraction: 0.4)) { squash = 0 }
            showPow(i)
            tileGone = true
            guard await pause(0.3) else { return }
            tileIndex = nil

            if let text = line(afterHit: i) {
                guard await pause(0.3) else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { bubble = text }
                guard await pause(i == 4 ? 1.7 : 0.9) else { return }
            } else {
                guard await pause(0.7) else { return }
            }
        }
        guard await pause(0.4) else { return }
        finished = true
    }

    @MainActor
    private func showPow(_ i: Int) {
        let k = i % Self.powWords.count
        pow = PowFx(word: Self.powWords[k], color: Color(hex: Self.powColors[k]),
                    x: i % 2 == 0 ? 96 : -96, rot: Double(i % 3) * 8 - 8)
        powShown = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { powShown = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.easeOut(duration: 0.25)) { powShown = false }
        }
    }
}

// MARK: - The brain

enum BrainMood { case happy, worried, dizzy, droopy, crying, dead, proud }

private enum BrainArt {
    static let ink = Color(hex: 0x2A1620)
    static let cream = Color(hex: 0xF4EFE8)
    static let body: [UInt32] = [0xFF9FBF, 0xF592B2, 0xDB9BAA, 0xC3A0A3, 0xAEA39C, 0x9AA595, 0x889F86]
    static let wrinkle: [UInt32] = [0xE2708F, 0xD3708A, 0xB67F8A, 0xA08184, 0x8C8478, 0x7A8A74, 0x6A826A]

    /// Circles that make up the brain, in a 320 by 280 drawing space.
    static let circles: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (90, 92, 48), (150, 66, 50), (215, 70, 50), (265, 108, 44), (60, 142, 44), (110, 142, 52), (170, 128, 52),
        (230, 142, 50), (275, 166, 40), (95, 194, 46), (155, 190, 50), (215, 198, 48), (252, 204, 36), (205, 232, 32)
    ]

    static let wrinkles: [(CGPoint, CGPoint, CGPoint)] = [
        (CGPoint(x: 88, y: 60), CGPoint(x: 110, y: 78), CGPoint(x: 96, y: 104)),
        (CGPoint(x: 200, y: 38), CGPoint(x: 184, y: 62), CGPoint(x: 206, y: 84)),
        (CGPoint(x: 255, y: 82), CGPoint(x: 238, y: 104), CGPoint(x: 262, y: 124)),
        (CGPoint(x: 48, y: 118), CGPoint(x: 72, y: 132), CGPoint(x: 58, y: 160)),
        (CGPoint(x: 232, y: 112), CGPoint(x: 216, y: 132), CGPoint(x: 238, y: 150)),
        (CGPoint(x: 270, y: 150), CGPoint(x: 252, y: 172), CGPoint(x: 270, y: 192)),
        (CGPoint(x: 110, y: 206), CGPoint(x: 132, y: 222), CGPoint(x: 150, y: 214)),
        (CGPoint(x: 222, y: 188), CGPoint(x: 240, y: 204), CGPoint(x: 226, y: 222)),
        (CGPoint(x: 70, y: 174), CGPoint(x: 84, y: 196), CGPoint(x: 106, y: 188))
    ]

    static let spiral: Path = {
        var p = Path()
        p.move(to: .zero)
        let n = 60
        for i in 1...n {
            let a = Double(i) / Double(n) * Double.pi * 6
            let r = Double(i) / Double(n) * 15
            p.addLine(to: CGPoint(x: cos(a) * r, y: sin(a) * r))
        }
        return p
    }()

    private static func eyeWhite(_ c: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat) {
        let r = CGRect(x: cx - 21, y: cy - 24, width: 42, height: 48)
        c.fill(Path(ellipseIn: r), with: .color(.white))
        c.stroke(Path(ellipseIn: r), with: .color(ink), lineWidth: 5)
    }

    private static func dot(_ c: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: Color) {
        c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color))
    }

    private static func curve(_ a: CGPoint, _ ctl: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        p.move(to: a)
        p.addQuadCurve(to: b, control: ctl)
        return p
    }

    private static func segment(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        return p
    }

    private static let stroke5 = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)

    private static func bigSmile(_ c: inout GraphicsContext) {
        var m = Path()
        m.move(to: CGPoint(x: 138, y: 178))
        m.addQuadCurve(to: CGPoint(x: 196, y: 178), control: CGPoint(x: 167, y: 218))
        m.closeSubpath()
        c.fill(m, with: .color(Color(hex: 0x7A1F3A)))
        c.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineJoin: .round))
        var tongue = Path()
        tongue.move(to: CGPoint(x: 152, y: 198))
        tongue.addQuadCurve(to: CGPoint(x: 182, y: 198), control: CGPoint(x: 167, y: 190))
        tongue.addQuadCurve(to: CGPoint(x: 152, y: 198), control: CGPoint(x: 167, y: 212))
        c.fill(tongue, with: .color(Color(hex: 0xFF6B8B)))
    }

    /// Draws the face in the 320 by 280 space. `t` is time in seconds, for the small loops.
    static func face(_ c: inout GraphicsContext, mood: BrainMood, body: Color, t: Double) {
        let eyes: [CGFloat] = [132, 202]
        let cy: CGFloat = 142
        switch mood {
        case .happy:
            for cx in eyes {
                eyeWhite(&c, cx, cy)
                dot(&c, cx + 2, cy + 2, 11, ink)
                dot(&c, cx + 7, cy - 4, 4, .white)
            }
            c.stroke(curve(CGPoint(x: 112, y: 106), CGPoint(x: 132, y: 94), CGPoint(x: 150, y: 104)), with: .color(ink), style: stroke5)
            c.stroke(curve(CGPoint(x: 184, y: 104), CGPoint(x: 202, y: 94), CGPoint(x: 222, y: 106)), with: .color(ink), style: stroke5)
            dot(&c, 104, 172, 9, Color(hex: 0xFF5C86).opacity(0.55))
            dot(&c, 230, 172, 9, Color(hex: 0xFF5C86).opacity(0.55))
            bigSmile(&c)
        case .proud:
            for cx in eyes {
                c.stroke(curve(CGPoint(x: cx - 17, y: 152), CGPoint(x: cx, y: 120), CGPoint(x: cx + 17, y: 152)),
                         with: .color(ink), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            }
            dot(&c, 104, 172, 10, Color(hex: 0xFF5C86).opacity(0.6))
            dot(&c, 230, 172, 10, Color(hex: 0xFF5C86).opacity(0.6))
            bigSmile(&c)
        case .worried:
            for cx in eyes {
                eyeWhite(&c, cx, cy)
                dot(&c, cx - 3, cy + 7, 6, ink)
            }
            c.stroke(curve(CGPoint(x: 146, y: 190), CGPoint(x: 167, y: 184), CGPoint(x: 190, y: 192)), with: .color(ink), style: stroke5)
            var sweat = Path()
            sweat.move(to: CGPoint(x: 244, y: 104))
            sweat.addQuadCurve(to: CGPoint(x: 244, y: 124), control: CGPoint(x: 252, y: 118))
            sweat.addQuadCurve(to: CGPoint(x: 244, y: 104), control: CGPoint(x: 236, y: 118))
            c.fill(sweat, with: .color(Color(hex: 0x9FD8FF)))
            c.stroke(sweat, with: .color(ink), lineWidth: 3)
        case .dizzy:
            for cx in eyes {
                eyeWhite(&c, cx, cy)
                var s = c
                s.translateBy(x: cx, y: cy)
                s.rotate(by: .radians(t * 9))
                s.stroke(spiral, with: .color(ink), style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
            }
            var w = Path()
            w.move(to: CGPoint(x: 140, y: 192))
            w.addQuadCurve(to: CGPoint(x: 158, y: 192), control: CGPoint(x: 149, y: 181))
            w.addQuadCurve(to: CGPoint(x: 176, y: 192), control: CGPoint(x: 167, y: 203))
            w.addQuadCurve(to: CGPoint(x: 194, y: 192), control: CGPoint(x: 185, y: 181))
            c.stroke(w, with: .color(ink), style: stroke5)
        case .droopy:
            for cx in eyes {
                eyeWhite(&c, cx, cy)
                dot(&c, cx, cy + 12, 7, ink)
                var lid = Path()
                lid.move(to: CGPoint(x: cx - 24, y: cy - 26))
                lid.addLine(to: CGPoint(x: cx + 24, y: cy - 26))
                lid.addLine(to: CGPoint(x: cx + 24, y: cy + 1))
                lid.addQuadCurve(to: CGPoint(x: cx - 24, y: cy + 1), control: CGPoint(x: cx, y: cy + 9))
                lid.closeSubpath()
                c.fill(lid, with: .color(body))
                c.stroke(lid, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineJoin: .round))
            }
            let mouth = CGRect(x: 153, y: 180, width: 28, height: 20)
            c.fill(Path(ellipseIn: mouth), with: .color(Color(hex: 0x5A1530)))
            c.stroke(Path(ellipseIn: mouth), with: .color(ink), lineWidth: 5)
            let drift = CGFloat((t * 1.1).truncatingRemainder(dividingBy: 1)) * 10
            var drool = Path()
            drool.move(to: CGPoint(x: 176, y: 198 + drift))
            drool.addQuadCurve(to: CGPoint(x: 176, y: 220 + drift), control: CGPoint(x: 185, y: 212 + drift))
            drool.addQuadCurve(to: CGPoint(x: 176, y: 198 + drift), control: CGPoint(x: 167, y: 212 + drift))
            c.fill(drool, with: .color(Color(hex: 0xBFE3FF)))
            c.stroke(drool, with: .color(ink), lineWidth: 3)
        case .crying:
            for cx in eyes {
                eyeWhite(&c, cx, cy)
                dot(&c, cx, cy + 3, 13, ink)
                dot(&c, cx + 4, cy - 2, 5, .white)
                dot(&c, cx - 4, cy + 8, 2.6, .white)
                let fall = CGFloat((t * 1.4).truncatingRemainder(dividingBy: 1))
                var tear = Path()
                tear.move(to: CGPoint(x: cx - 12, y: cy + 22 + fall * 14))
                tear.addQuadCurve(to: CGPoint(x: cx - 12, y: cy + 42 + fall * 14), control: CGPoint(x: cx - 19, y: cy + 36 + fall * 14))
                tear.addQuadCurve(to: CGPoint(x: cx - 12, y: cy + 22 + fall * 14), control: CGPoint(x: cx - 5, y: cy + 36 + fall * 14))
                c.fill(tear, with: .color(Color(hex: 0x9FD8FF).opacity(1 - Double(fall) * 0.7)))
                c.stroke(tear, with: .color(ink), lineWidth: 3)
            }
            c.stroke(segment(CGPoint(x: 106, y: 112), CGPoint(x: 150, y: 98)), with: .color(ink), style: stroke5)
            c.stroke(segment(CGPoint(x: 222, y: 98), CGPoint(x: 262, y: 112)), with: .color(ink), style: stroke5)
            var w = Path()
            w.move(to: CGPoint(x: 140, y: 200))
            w.addQuadCurve(to: CGPoint(x: 160, y: 200), control: CGPoint(x: 150, y: 186))
            w.addQuadCurve(to: CGPoint(x: 180, y: 200), control: CGPoint(x: 170, y: 186))
            w.addQuadCurve(to: CGPoint(x: 196, y: 198), control: CGPoint(x: 190, y: 186))
            c.stroke(w, with: .color(ink), style: stroke5)
        case .dead:
            for cx in eyes {
                c.stroke(segment(CGPoint(x: cx - 15, y: cy - 15), CGPoint(x: cx + 15, y: cy + 15)), with: .color(ink),
                         style: StrokeStyle(lineWidth: 8, lineCap: .round))
                c.stroke(segment(CGPoint(x: cx + 15, y: cy - 15), CGPoint(x: cx - 15, y: cy + 15)), with: .color(ink),
                         style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }
            c.stroke(segment(CGPoint(x: 146, y: 188), CGPoint(x: 188, y: 188)), with: .color(ink), style: stroke5)
            var tongue = Path()
            tongue.move(to: CGPoint(x: 164, y: 190))
            tongue.addLine(to: CGPoint(x: 164, y: 214))
            tongue.addQuadCurve(to: CGPoint(x: 180, y: 214), control: CGPoint(x: 172, y: 228))
            tongue.addLine(to: CGPoint(x: 180, y: 190))
            tongue.closeSubpath()
            c.fill(tongue, with: .color(Color(hex: 0xC97A8E)))
            c.stroke(tongue, with: .color(ink), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
        }
    }
}

/// The union of the brain circles. `grow` fattens it, for the outline passes.
private struct BrainBlob: Shape {
    var grow: CGFloat

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width / 320, rect.height / 280)
        let dx = rect.minX + (rect.width - 320 * s) / 2
        let dy = rect.minY + (rect.height - 280 * s) / 2
        var p = Path()
        for c in BrainArt.circles {
            let r = (c.r + grow) * s
            p.addEllipse(in: CGRect(x: dx + c.x * s - r, y: dy + c.y * s - r, width: r * 2, height: r * 2))
        }
        let w = 20 + grow * 2
        let stem = CGRect(x: dx + (165 - w / 2) * s, y: dy + (238 - grow / 2) * s, width: w * s, height: (36 + grow) * s)
        p.addRoundedRect(in: stem, cornerSize: CGSize(width: 9 * s, height: 9 * s))
        return p
    }
}

private struct BrainWrinkles: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width / 320, rect.height / 280)
        var p = Path()
        for w in BrainArt.wrinkles {
            p.move(to: CGPoint(x: w.0.x * s, y: w.0.y * s))
            p.addQuadCurve(to: CGPoint(x: w.2.x * s, y: w.2.y * s), control: CGPoint(x: w.1.x * s, y: w.1.y * s))
        }
        return p
    }
}

private struct BrainCracks: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width / 320, rect.height / 280)
        let lines: [[CGPoint]] = [
            [CGPoint(x: 150, y: 40), CGPoint(x: 162, y: 70), CGPoint(x: 146, y: 92), CGPoint(x: 160, y: 116)],
            [CGPoint(x: 250, y: 130), CGPoint(x: 232, y: 148), CGPoint(x: 246, y: 166)]
        ]
        var p = Path()
        for l in lines {
            for (k, pt) in l.enumerated() {
                let q = CGPoint(x: pt.x * s, y: pt.y * s)
                if k == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
        }
        return p
    }
}

private struct BrainView: View {
    let damage: Int
    let mood: BrainMood
    let squash: CGFloat
    let reduce: Bool
    let proud: Bool
    let size: CGFloat

    private var s: CGFloat { size / 320 }

    var body: some View {
        let bodyColor = Color(hex: BrainArt.body[damage])
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduce)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let wobble = Self.wobble(t: t, damage: damage, reduce: reduce)
            ZStack(alignment: .topLeading) {
                BrainBlob(grow: 12).fill(BrainArt.cream)
                BrainBlob(grow: 5).fill(BrainArt.ink)
                BrainBlob(grow: 0).fill(bodyColor)
                BrainWrinkles()
                    .stroke(Color(hex: BrainArt.wrinkle[damage]), style: StrokeStyle(lineWidth: 5 * s, lineCap: .round))
                if damage >= 5 {
                    BrainCracks()
                        .stroke(BrainArt.ink, style: StrokeStyle(lineWidth: 4 * s, lineCap: .round, lineJoin: .round))
                }
                Canvas { context, canvasSize in
                    context.scaleBy(x: canvasSize.width / 320, y: canvasSize.height / 280)
                    BrainArt.face(&context, mood: mood, body: bodyColor, t: t)
                }
                if damage >= 6 {
                    Ellipse()
                        .stroke(Color(hex: 0xFFD65A), lineWidth: 7 * s)
                        .frame(width: 92 * s, height: 22 * s)
                        .position(x: 165 * s, y: (6 + CGFloat(sin(t * 3)) * 3) * s)
                    ForEach(0..<2, id: \.self) { k in
                        let a: Double = t * (k == 0 ? 3.6 : 4.6) + Double(k) * 2
                        let rx: CGFloat = k == 0 ? 64 : 50
                        let ry: CGFloat = k == 0 ? 26 : 20
                        Circle()
                            .fill(BrainArt.ink)
                            .frame(width: 10 * s, height: 10 * s)
                            .position(x: (165 + CGFloat(cos(a)) * rx) * s, y: (-8 + CGFloat(sin(a)) * ry) * s)
                    }
                }
            }
            .frame(width: size, height: 280 * s)
            .offset(x: wobble.width, y: wobble.height)
        }
        .frame(width: size, height: 280 * s)
        .rotationEffect(.degrees(Double(-damage) * 2))
        .offset(y: CGFloat(damage) * 6)
        .scaleEffect(x: 1 + squash * 0.2, y: (1 - CGFloat(damage) * 0.025) - squash * 0.26, anchor: .bottom)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: damage)
        .frame(maxWidth: .infinity)
    }

    /// A slow bob while the brain is fine, a shake when it begs, nothing once it is gone.
    private static func wobble(t: Double, damage: Int, reduce: Bool) -> CGSize {
        if reduce { return .zero }
        switch damage {
        case 0...3:
            let amp = 10.0 - Double(damage) * 2.4
            let period = 1.3 + Double(damage) * 0.4
            return CGSize(width: 0, height: CGFloat(-(sin(t * 2 * .pi / period) * 0.5 + 0.5) * amp))
        case 4, 5:
            return CGSize(width: CGFloat(sin(t * 2 * .pi * 6) * 3), height: 0)
        default:
            return .zero
        }
    }
}

// MARK: - Comic bits

/// One app-style tile that drops onto the brain. It starts its fall as soon as it appears, and is
/// shrunk away by the parent after it lands.
private struct BrainFallingTile: View {
    let symbol: String
    let color: Color
    let x: CGFloat
    let spin: Double
    let landY: CGFloat
    let gone: Bool

    @State private var dropped = false

    var body: some View {
        SymbolTile(symbol: symbol, color: color, size: 76, tilt: dropped ? spin : 0)
            .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 6)
            .overlay(alignment: .top) {
                // Speed streaks above the tile while it falls.
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(Color.white.opacity(0.35)).frame(width: 3, height: 26)
                    }
                }
                .offset(y: -34)
                .opacity(dropped ? 0 : 1)
            }
            .offset(x: x, y: dropped ? landY : -20)
            .scaleEffect(gone ? 0.05 : 1)
            .opacity(gone ? 0 : 1)
            .animation(.easeOut(duration: 0.25), value: gone)
            .onAppear {
                withAnimation(.easeIn(duration: 0.6)) { dropped = true }
            }
            .accessibilityHidden(true)
    }
}

private struct BrainStarburst: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let n = 20
        var p = Path()
        for k in 0..<n {
            let a = Double(k) / Double(n) * 2 * Double.pi
            let r = (k % 2 == 0 ? rect.width * 0.48 : rect.width * 0.28)
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct BrainPowBurst: View {
    let word: String
    let color: Color

    var body: some View {
        ZStack {
            BrainStarburst().fill(color)
            BrainStarburst().stroke(BrainArt.ink, style: StrokeStyle(lineWidth: 5, lineJoin: .round))
            Text(word)
                .font(Cream.rounded(22, .heavy))
                .foregroundStyle(BrainArt.ink)
                .rotationEffect(.degrees(-6))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .accessibilityHidden(true)
    }
}

private struct BrainTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// What the brain says. A cream bubble with a dark edge, tilted a little.
private struct BrainSpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Cream.rounded(22, .heavy))
            .kerning(-0.5)
            .foregroundStyle(BrainArt.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(BrainArt.cream))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(BrainArt.ink, lineWidth: 4))
            .overlay(alignment: .top) {
                ZStack {
                    BrainTail().fill(BrainArt.ink).frame(width: 28, height: 16)
                    BrainTail().fill(BrainArt.cream).frame(width: 20, height: 11).offset(y: 3)
                }
                .offset(y: -15)
            }
            .rotationEffect(.degrees(-2))
    }
}

private struct BrainStar4: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX + w * 0.04, y: rect.midY - h * 0.04))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.midX + w * 0.04, y: rect.midY + h * 0.04))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX - w * 0.04, y: rect.midY + h * 0.04))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX - w * 0.04, y: rect.midY - h * 0.04))
        p.closeSubpath()
        return p
    }
}

/// Four little stars around the proud brain.
private struct BrainSparkles: View {
    let reduce: Bool
    @State private var on = false

    private static let spots: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (-150, 90, 26), (146, 100, 22), (-124, 250, 20), (120, 258, 28)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.spots.enumerated()), id: \.offset) { k, spot in
                let twinkle: Animation? = reduce
                    ? nil
                    : Animation.easeInOut(duration: 0.9 + Double(k) * 0.15).repeatForever(autoreverses: true).delay(Double(k) * 0.14)
                BrainStar4()
                    .fill(Color(hex: 0xFFD65A))
                    .overlay(BrainStar4().stroke(BrainArt.ink, lineWidth: 1.6))
                    .frame(width: spot.size, height: spot.size)
                    .scaleEffect(on || reduce ? 1 : 0.2)
                    .rotationEffect(.degrees(on && !reduce ? 40 : 0))
                    .opacity(on || reduce ? 1 : 0)
                    .offset(x: spot.x, y: spot.y)
                    .animation(twinkle, value: on)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityHidden(true)
        .onAppear { on = true }
    }
}
