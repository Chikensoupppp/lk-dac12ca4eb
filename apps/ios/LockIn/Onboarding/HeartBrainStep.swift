import SwiftUI

/// Slide 5: "This is your brain over one day." A heart monitor and a printed pink brain.
/// One app tile hits the brain per chunk of the day; the monitor clock counts the time on the
/// phone. The heart rate only climbs (72 to 188), skips beats, shakes, then flatlines, so more
/// hours never looks calmer. At the end the brain shrinks and a card shows what studies found
/// for that many hours. Mock: docs/design/brain-v2.html. It is a picture, not a diagnosis; the
/// card says "links, not proof".
struct HeartBrainStep: View {
    let hoursIndex: Int
    let next: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduce: Bool { effectiveReduceMotion(systemReduceMotion) }

    @State private var stage = 0
    @State private var hitCount = 0
    @State private var minutes: Double = 0
    @State private var squash: CGFloat = 0
    @State private var bubble: String?
    @State private var status = HeartArt.status[0]
    @State private var tileIndex: Int?
    /// 0 above the screen, 1 on the brain, 2 gone.
    @State private var tilePhase = 0
    @State private var pow: String?
    @State private var powLeft = true
    @State private var notesShown = false

    private var index: Int { min(max(hoursIndex, 0), 3) }
    private var hits: Int { [1, 2, 4, 5][index] }
    private var maxStage: Int { [1, 2, 4, 5][index] }
    private var hours: Double { [1.5, 3.5, 5.5, 7.5][index] }
    private static let titles = ["1\u{2013}2 hours\na day.", "3\u{2013}4 hours\na day.", "5\u{2013}6 hours\na day.", "7+ hours\na day."]

    var body: some View {
        PrintScaffold(step: 5, background: HeartArt.bg, foreground: HeartArt.cream, title: Self.titles[index],
                      titleSize: 46, primaryTitle: "CONTINUE", primaryAction: next) {
            VStack(alignment: .leading, spacing: 14) {
                Text("This is your brain over one day.\nEach hit = more time on your phone.")
                    .font(PrintFont.bold(18))
                    .foregroundStyle(HeartArt.cream.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                monitor
                chips
                brainArea
                if !notesShown {
                    Text(status.uppercased())
                        .font(PrintFont.head(30))
                        .foregroundStyle(HeartArt.cream)
                        .contentTransition(.opacity)
                        .accessibilityLabel(status)
                } else {
                    StudyCard(hours: hours)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.85), value: notesShown)
            .keyframeAnimator(initialValue: CGFloat(0), trigger: hitCount) { content, x in
                content.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-6, duration: 0.06)
                    CubicKeyframe(5, duration: 0.06)
                    CubicKeyframe(-3, duration: 0.06)
                    CubicKeyframe(0, duration: 0.08)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: hitCount)
        .task { await run() }
    }

    // MARK: Heart monitor

    private var monitor: some View {
        TimelineView(.animation(paused: reduce)) { context in
            let t = reduce ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    var grid = Path()
                    var x: CGFloat = 0
                    while x < size.width { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)); x += 16 }
                    var y: CGFloat = 0
                    while y < size.height { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)); y += 16 }
                    ctx.stroke(grid, with: .color(HeartArt.grid), lineWidth: 1)
                    let line = HeartArt.ecg(stage: stage, t: t, width: size.width - 70)
                    let color = stage == 5 ? HeartArt.alarm : HeartArt.green
                    var glow = ctx
                    glow.addFilter(.blur(radius: 4))
                    glow.stroke(line, with: .color(color.opacity(0.8)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                Text(HeartArt.clock(minutes))
                    .font(PrintFont.mono(12, .heavy))
                    .foregroundStyle(stage >= 4 ? HeartArt.alarm : HeartArt.green)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(HeartArt.panel))
                    .padding(.leading, 12).padding(.top, 9)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(HeartArt.bpm(stage: stage, t: t))")
                        .font(PrintFont.mono(30, .heavy))
                        .monospacedDigit()
                    Text("BPM").font(PrintFont.mono(10)).tracking(2).opacity(0.7)
                }
                .foregroundStyle(HeartArt.bpmColor(stage))
                .opacity(stage == 4 && Int(t / 0.3) % 2 == 1 ? 0.25 : 1)
                .padding(.top, 12).padding(.trailing, 14)
                .frame(width: 92, alignment: .trailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .background(alignment: .trailing) {
                    LinearGradient(colors: [HeartArt.panel.opacity(0), HeartArt.panel], startPoint: .leading, endPoint: UnitPoint(x: 0.22, y: 0.5))
                        .frame(width: 92)
                }
            }
        }
        .frame(height: 96)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(HeartArt.panel))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(hex: 0x1F4238), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart monitor. \(HeartArt.clock(minutes)). \(HeartArt.bpmBase[stage]) beats a minute.")
    }

    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(0..<hits, id: \.self) { i in
                let on = i < hitCount
                Image(systemName: HeartArt.tiles[i].symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(on ? Color.white : Color(hex: 0x4E7A6D))
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(on ? HeartArt.tiles[i].color : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(on ? Color.clear : Color(hex: 0x2A4A41), lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: The brain

    private var brainArea: some View {
        ZStack(alignment: .top) {
            TimelineView(.animation(paused: reduce)) { context in
                let t = reduce ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
                Canvas { ctx, size in
                    let s = min(size.width / 364, size.height / 300)
                    ctx.translateBy(x: (size.width - 364 * s) / 2, y: 0)
                    ctx.scaleBy(x: s, y: s)
                    HeartArt.drawBrain(in: &ctx, stage: stage, t: t)
                }
            }
            .scaleEffect(x: 1 + squash * 0.08, y: 1 - squash * 0.12, anchor: .bottom)
            .frame(height: 300)

            if let tileIndex {
                let tile = HeartArt.tiles[tileIndex]
                Image(systemName: tile.symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tile.color))
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 8)
                    .rotationEffect(.degrees(tilePhase == 0 ? 0 : (tileIndex % 2 == 0 ? -220 : 220)))
                    .scaleEffect(tilePhase == 2 ? 0.2 : 1)
                    .opacity(tilePhase == 2 ? 0 : 1)
                    .offset(x: tileIndex % 2 == 0 ? -30 : 40, y: ([-420, 20, 40] as [CGFloat])[tilePhase])
                    .zIndex(3)
            }

            if let pow {
                Text(pow)
                    .font(PrintFont.head(34))
                    .foregroundStyle(HeartArt.bg)
                    .padding(.horizontal, 22).padding(.vertical, 18)
                    .background(BurstShape().fill(Color(hex: 0xFFE14D)))
                    .rotationEffect(.degrees(-8))
                    .frame(maxWidth: .infinity, alignment: powLeft ? .leading : .trailing)
                    .offset(y: 30)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .zIndex(4)
            }

            if let bubble {
                SpeechBubble(text: bubble)
                    .rotationEffect(.degrees(3))
                    .frame(maxWidth: .infinity, alignment: stage == 4 ? .center : .trailing)
                    .offset(y: -6)
                    .transition(.scale(scale: 0.3, anchor: .bottomLeading).combined(with: .opacity))
                    .zIndex(5)
            }
        }
        // At the end the brain gets small and moves aside for the study card.
        .scaleEffect(notesShown ? 0.48 : 1, anchor: .topTrailing)
        .frame(height: notesShown ? 150 : 300, alignment: .top)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A cartoon brain. \(status)")
    }

    // MARK: The run

    @MainActor
    private func run() async {
        if reduce {
            stage = hits == 1 ? 0 : maxStage
            hitCount = hits
            minutes = hours * 60
            status = hits == 1 ? "Well done. Keep it like that." : HeartArt.status[maxStage]
            notesShown = true
            return
        }
        guard await printPause(0.9) else { return }
        for i in 0..<hits {
            // Fall from above onto the brain, then shrink away.
            tilePhase = 0
            tileIndex = i
            guard await printPause(0.05) else { return }
            withAnimation(.timingCurve(0.55, 0, 1, 0.6, duration: 0.65)) { tilePhase = 1 }
            guard await printPause(0.62) else { return }
            withAnimation(.easeOut(duration: 0.2)) { tilePhase = 2 }

            withAnimation(.easeOut(duration: 0.15)) { bubble = nil }
            stage = Int((Double(i + 1) * Double(maxStage) / Double(hits)).rounded())
            hitCount = i + 1
            minutes = hours * 60 * Double(i + 1) / Double(hits)
            squash = 1
            withAnimation(.spring(response: 0.45, dampingFraction: 0.4)) { squash = 0 }
            powLeft = i % 2 == 0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { pow = HeartArt.pows[i % HeartArt.pows.count] }
            withAnimation(.easeOut(duration: 0.2)) { status = HeartArt.status[stage] }
            Task { @MainActor in
                _ = await printPause(0.6)
                withAnimation(.easeOut(duration: 0.2)) { pow = nil }
            }
            guard await printPause(0.45) else { return }
            tileIndex = nil

            if let line = HeartArt.lines[stage], i < hits - 1 || stage == 4 {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.6)) { bubble = line }
                guard await printPause(stage == 4 ? 1.7 : 1.1) else { return }
            } else {
                guard await printPause(0.7) else { return }
            }
        }
        if hits == 1 {
            // A light day takes one small knock, then bounces back.
            stage = 0
            squash = 1
            withAnimation(.spring(response: 0.45, dampingFraction: 0.4)) { squash = 0 }
            status = "Well done. Keep it like that."
            withAnimation(.spring(response: 0.36, dampingFraction: 0.6)) { bubble = "I feel great!" }
        } else if stage == 5 {
            withAnimation(.easeOut(duration: 0.2)) { bubble = nil }
        }
        guard await printPause(1.8) else { return }
        withAnimation(.easeOut(duration: 0.2)) { bubble = nil }
        notesShown = true
    }
}

// MARK: - Study card

/// Three findings picked by hours, one marked "you are here". Plain summaries of the studies,
/// not quotes; sources are listed in docs/ONBOARDING_V2.md. All show links, not cause.
private struct StudyCard: View {
    let hours: Double

    private struct Note {
        let tag: String
        let text: String
        let source: String
    }

    private static let m30 = Note(tag: "30 MIN", text: "Students who cut social media to 30 min a day felt less lonely and less depressed in 3 weeks.", source: "U. of Pennsylvania, 2018")
    private static let mod = Note(tag: "1\u{2013}2H", text: "Up to about 2 hours a day was not linked to harm in 120,000 teens.", source: "Oxford, Psychological Science, 2017")
    private static let h3 = Note(tag: "3H+", text: "Teens on social media over 3 hours a day had 1.6\u{00D7} the risk of anxiety and depression signs.", source: "Johns Hopkins, JAMA Psychiatry, 2019")
    private static let h6 = Note(tag: "6H+", text: "Over 6 hours a day, that risk went up to 1.8\u{00D7}.", source: "Johns Hopkins, JAMA Psychiatry, 2019")
    private static let h7 = Note(tag: "7H+", text: "Teens on screens 7+ hours a day were over 2\u{00D7} as likely to be diagnosed with depression or anxiety.", source: "Twenge & Campbell, 2018")
    private static let sleep = Note(tag: "SLEEP", text: "More screen time meant worse sleep in 9 of 10 studies.", source: "Sleep Medicine Reviews, 2015")

    /// (note, is good news, is "you")
    private var rows: (head: String, items: [(Note, Bool, Bool)]) {
        if hours < 2.5 { return ("GOOD NEWS \u{00B7} WHAT STUDIES FOUND", [(Self.mod, true, true), (Self.m30, true, false), (Self.h3, false, false)]) }
        if hours < 5 { return ("WHAT STUDIES FOUND", [(Self.mod, true, false), (Self.h3, false, true), (Self.sleep, false, false)]) }
        if hours < 6 { return ("WHAT STUDIES FOUND", [(Self.h3, false, true), (Self.h6, false, false), (Self.sleep, false, false)]) }
        if hours < 7 { return ("WHAT STUDIES FOUND", [(Self.h3, false, false), (Self.h6, false, true), (Self.sleep, false, false)]) }
        return ("WHAT STUDIES FOUND", [(Self.h3, false, false), (Self.h6, false, false), (Self.h7, false, true)])
    }

    var body: some View {
        let r = rows
        VStack(alignment: .leading, spacing: 0) {
            Text(r.head)
                .font(PrintFont.mono(11, .heavy)).tracking(2)
                .foregroundStyle(Color(hex: 0xC42B2B))
                .padding(.bottom, 4)
            ForEach(Array(r.items.enumerated()), id: \.offset) { _, item in
                let note = item.0
                let good = item.1
                let you = item.2
                HStack(alignment: .top, spacing: 10) {
                    Text(note.tag)
                        .font(PrintFont.mono(11, .heavy))
                        .foregroundStyle(Ink.paper)
                        .frame(width: 56, height: 26)
                        .background(Capsule().fill(you ? HeartArt.alarm : good ? Color(hex: 0x17824A) : HeartArt.bg))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.text)
                            .font(PrintFont.bold(16))
                            .fixedSize(horizontal: false, vertical: true)
                        (you ? Text("YOU ARE HERE \u{00B7} ").foregroundColor(good ? Color(hex: 0x17824A) : Color(hex: 0xC42B2B)).bold() : Text(""))
                            + Text(note.source).foregroundColor(HeartArt.bg.opacity(0.62))
                    }
                    .font(PrintFont.mono(10, .medium))
                }
                .foregroundStyle(HeartArt.bg)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(HeartArt.bg.opacity(0.15)).frame(height: 1.5)
                }
                .accessibilityElement(children: .combine)
            }
            Text("Studies show links, not proof. Not medical advice.")
                .font(PrintFont.mono(10, .regular))
                .foregroundStyle(HeartArt.bg.opacity(0.55))
                .padding(.top, 8)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(HeartArt.cream))
    }
}

// MARK: - Small pieces

private struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(PrintFont.bold(21))
            .foregroundStyle(HeartArt.bg)
            .padding(.horizontal, 15).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(HeartArt.cream))
            .overlay(alignment: .bottomLeading) {
                Triangle().fill(HeartArt.cream).frame(width: 16, height: 12).offset(x: 22, y: 11)
            }
            .fixedSize()
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// The comic "POW" burst.
private struct BurstShape: Shape {
    func path(in r: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [(0.5, 0), (0.61, 0.22), (0.86, 0.08), (0.80, 0.34), (1, 0.45), (0.79, 0.58),
                                         (0.92, 0.84), (0.64, 0.76), (0.52, 1), (0.40, 0.77), (0.12, 0.90), (0.22, 0.62),
                                         (0, 0.48), (0.21, 0.36), (0.12, 0.10), (0.39, 0.22)]
        var p = Path()
        for (i, pt) in pts.enumerated() {
            let point = CGPoint(x: r.minX + pt.0 * r.width, y: r.minY + pt.1 * r.height)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Art and numbers

private enum HeartArt {
    static let bg = Color(hex: 0x0B1A16)
    static let panel = Color(hex: 0x10241F)
    static let grid = Color(hex: 0x16332B)
    static let green = Color(hex: 0x4BFF9A)
    static let alarm = Color(hex: 0xFF3B3B)
    static let yellow = Color(hex: 0xFFC233)
    static let cream = Color(hex: 0xF2ECE1)
    static let tear = Color(hex: 0x7FD8FF)
    static let tongue = Color(hex: 0xFF8FB8)
    static let stink = Color(hex: 0x8C9670)

    /// Body color per stage: hot pink drains to a sick grey-green.
    static let body: [Color] = ([0xFF5FA2, 0xFF7AA6, 0xEE93A0, 0xCFA08C, 0xADA37A, 0x8C9670] as [UInt32]).map { Color(hex: $0) }
    static let bpmBase = [72, 98, 126, 154, 188, 0]
    static let lines: [String?] = [nil, "just 1 more\u{2026}", "ok, 1 more\u{2026}", "12 more minutes\u{2026}", "no more brain rot plsss\u{2026}", nil]
    static let status = ["Your brain feels fine.", "Your brain is tired.", "Your brain is dizzy.", "Your brain is fading.", "Your brain is begging.", "Your brain is gone."]
    static let pows = ["BONK!", "POW!", "WHAM!", "SMACK!", "K.O."]
    /// Generic app tiles, no real logos.
    static let tiles: [(symbol: String, color: Color)] = [
        ("play.fill", Color(hex: 0xE5484D)), ("circle.circle.fill", Color(hex: 0x8E4EC6)), ("music.note", Color(hex: 0x2B2F36)),
        ("envelope.fill", Color(hex: 0x3E63DD)), ("heart.fill", Color(hex: 0xD6336C))
    ]

    static func clock(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        return "TIME ON PHONE \u{00B7} \(m / 60)H \(String(format: "%02d", m % 60))M"
    }

    /// Real monitors drift a few beats; this wobbles the number about every 0.7 s.
    static func bpm(stage: Int, t: Double) -> Int {
        let base = bpmBase[stage]
        guard stage > 0, stage < 5 else { return base }
        let k = Double(Int(t * 1.5))
        let r = abs(sin(k * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
        return base + Int(r * 6) - 3
    }

    static func bpmColor(_ stage: Int) -> Color {
        switch stage {
        case 5, 4: return alarm
        case 3: return yellow
        default: return green
        }
    }

    /// The trace. The strip scrolls at a fixed speed, so a faster heart puts beats closer together.
    /// Stage 3 skips beats, stage 4 has no clear beats (chaotic), stage 5 is flat.
    static func ecg(stage: Int, t: Double, width: CGFloat) -> Path {
        let mid: CGFloat = 58
        let amp: CGFloat = [34, 34, 32, 30, 0, 0][stage]
        let period = stage < 5 ? 90 * 72 / Double(bpmBase[stage]) : 90
        var p = Path()
        p.move(to: CGPoint(x: 0, y: mid))
        var x: CGFloat = 0
        while x <= width {
            var y = mid
            let xd = Double(x)
            if stage == 4 {
                y = mid + CGFloat(sin(xd * 0.21 + t * 9) * 11 + sin(xd * 0.53 + t * 13) * 7 + sin(xd * 0.09 - t * 5) * 6)
            } else if amp > 0 {
                let pos = (xd + t * 108) / period
                let n = Int(pos.rounded(.down))
                let ph = pos - Double(n)
                let skip = stage == 3 && n % 4 == 2
                let a = amp * (stage == 3 && n % 3 == 0 ? 0.7 : 1)
                if !skip {
                    if ph > 0.30 && ph < 0.36 { y = mid - a * 0.22 }
                    else if ph > 0.42 && ph < 0.46 { y = mid + a * 0.22 }
                    else if ph >= 0.46 && ph < 0.50 { y = mid - a }
                    else if ph >= 0.50 && ph < 0.54 { y = mid + a * 0.45 }
                    else if ph > 0.64 && ph < 0.76 { y = mid - a * 0.22 }
                }
            }
            p.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }
        return p
    }

    // The brain outline, in a 364 by 300 drawing space.
    static let outline: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 70, y: 132))
        p.addCurve(to: CGPoint(x: 132, y: 48), control1: CGPoint(x: 36, y: 88), control2: CGPoint(x: 80, y: 32))
        p.addCurve(to: CGPoint(x: 232, y: 48), control1: CGPoint(x: 150, y: 10), control2: CGPoint(x: 216, y: 10))
        p.addCurve(to: CGPoint(x: 298, y: 126), control1: CGPoint(x: 282, y: 32), control2: CGPoint(x: 322, y: 82))
        p.addCurve(to: CGPoint(x: 264, y: 216), control1: CGPoint(x: 332, y: 154), control2: CGPoint(x: 314, y: 216))
        p.addCurve(to: CGPoint(x: 170, y: 232), control1: CGPoint(x: 252, y: 250), control2: CGPoint(x: 198, y: 260))
        p.addCurve(to: CGPoint(x: 74, y: 204), control1: CGPoint(x: 136, y: 260), control2: CGPoint(x: 74, y: 242))
        p.addCurve(to: CGPoint(x: 70, y: 132), control1: CGPoint(x: 34, y: 192), control2: CGPoint(x: 30, y: 142))
        p.closeSubpath()
        return p
    }()

    static let wrinkles: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 132, y: 50)); p.addCurve(to: CGPoint(x: 164, y: 98), control1: CGPoint(x: 126, y: 76), control2: CGPoint(x: 142, y: 92))
        p.move(to: CGPoint(x: 232, y: 50)); p.addCurve(to: CGPoint(x: 200, y: 98), control1: CGPoint(x: 238, y: 76), control2: CGPoint(x: 222, y: 92))
        p.move(to: CGPoint(x: 100, y: 176)); p.addCurve(to: CGPoint(x: 154, y: 192), control1: CGPoint(x: 122, y: 166), control2: CGPoint(x: 144, y: 176))
        p.move(to: CGPoint(x: 264, y: 168)); p.addCurve(to: CGPoint(x: 220, y: 188), control1: CGPoint(x: 248, y: 162), control2: CGPoint(x: 226, y: 172))
        return p
    }()

    /// The halftone dots, built once.
    static let dots: Path = {
        var p = Path()
        var y: CGFloat = 0
        while y < 300 {
            var x: CGFloat = 0
            while x < 364 {
                p.addEllipse(in: CGRect(x: x + 0.8, y: y + 0.8, width: 5.4, height: 5.4))
                x += 7
            }
            y += 7
        }
        return p
    }()

    private static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private static func line(_ pts: [CGPoint]) -> Path {
        var p = Path()
        if let first = pts.first { p.move(to: first) }
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }

    private static func bandage(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, angle: Double, pivot: CGPoint, slits: Bool) {
        var c = ctx
        c.translateBy(x: pivot.x, y: pivot.y)
        c.rotate(by: .degrees(angle))
        c.translateBy(x: -pivot.x, y: -pivot.y)
        let rect = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 6)
        c.fill(rect, with: .color(cream))
        c.stroke(rect, with: .color(bg), lineWidth: 4)
        if slits {
            var s = Path()
            for sx in [x + 22, x + 30, x + 38] { s.move(to: CGPoint(x: sx, y: y + 4)); s.addLine(to: CGPoint(x: sx, y: y + 18)) }
            c.stroke(s, with: .color(bg), lineWidth: 2.5)
        }
    }

    static func drawBrain(in ctx: inout GraphicsContext, stage st: Int, t: Double) {
        let color = body[st]
        let ink = bg
        let round = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        let sway = st >= 3 ? sin(t * 1.4) * Double(st - 2) * 1.6 : sin(t * 2) * 1.2
        let droop: CGFloat = [0, 0, 0, 6, 10, 18][st]
        let shake: CGFloat = st == 4 ? CGFloat(sin(t * 40) * 1.4) : 0

        var c = ctx
        c.translateBy(x: shake, y: droop)
        c.translateBy(x: 182, y: 150)
        c.rotate(by: .degrees(sway + Double(droop) * 0.4))
        c.translateBy(x: -182, y: -150)

        // Body: soft offset shadow, halftone dots, cream outline, folds.
        c.fill(outline.applying(CGAffineTransform(translationX: 7, y: 6)), with: .color(color.opacity(0.35)))
        var dotted = c
        dotted.clip(to: outline)
        dotted.fill(dots, with: .color(color))
        c.stroke(outline, with: .color(cream), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
        c.stroke(wrinkles, with: .color(cream.opacity(0.7)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // Damage that stays.
        if st == 1 {
            var drop = Path()
            drop.move(to: CGPoint(x: 262, y: 96))
            drop.addQuadCurve(to: CGPoint(x: 262, y: 118), control: CGPoint(x: 270, y: 110))
            drop.addQuadCurve(to: CGPoint(x: 262, y: 96), control: CGPoint(x: 254, y: 110))
            c.fill(drop, with: .color(tear))
            c.stroke(drop, with: .color(ink), lineWidth: 3)
        }
        if st >= 2 { bandage(&c, x: 92, y: 78, w: 60, h: 22, angle: -24, pivot: CGPoint(x: 120, y: 90), slits: true) }
        if st >= 3 {
            c.stroke(line([CGPoint(x: 232, y: 60), CGPoint(x: 222, y: 82), CGPoint(x: 236, y: 90), CGPoint(x: 224, y: 114)]),
                     with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        if st >= 4 {
            c.stroke(line([CGPoint(x: 86, y: 196), CGPoint(x: 104, y: 202), CGPoint(x: 98, y: 216), CGPoint(x: 114, y: 226)]),
                     with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            bandage(&c, x: 244, y: 160, w: 56, h: 20, angle: 20, pivot: CGPoint(x: 270, y: 170), slits: false)
        }
        if st == 5 {
            for i in 0..<3 {
                let x = CGFloat(130 + i * 50)
                let y0 = CGFloat(40 - (t * 30 + Double(i) * 10).truncatingRemainder(dividingBy: 30))
                var s = Path()
                s.move(to: CGPoint(x: x, y: y0))
                s.addQuadCurve(to: CGPoint(x: x, y: y0 - 20), control: CGPoint(x: x - 8, y: y0 - 10))
                s.addQuadCurve(to: CGPoint(x: x, y: y0 - 40), control: CGPoint(x: x + 8, y: y0 - 30))
                c.stroke(s, with: .color(stink.opacity(0.8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            for i in 0..<2 {
                let a = t * 3 + Double(i) * 3
                let fx = CGFloat(182 + cos(a) * 130), fy = CGFloat(120 + sin(a * 1.3) * 60)
                c.fill(circle(fx, fy, 4), with: .color(cream))
                c.fill(Path(ellipseIn: CGRect(x: fx - 9, y: fy - 8, width: 10, height: 6)), with: .color(cream.opacity(0.5)))
            }
        }

        // Eyes.
        let ey: CGFloat = 150
        for (i, x) in [CGFloat(150), CGFloat(214)].enumerated() {
            switch st {
            case 0:
                c.fill(circle(x, ey, 17), with: .color(cream)); c.stroke(circle(x, ey, 17), with: .color(ink), lineWidth: 5)
                c.fill(circle(x + 3, ey + 2, 8), with: .color(ink)); c.fill(circle(x + 6, ey - 2, 3), with: .color(cream))
            case 1:
                c.fill(circle(x, ey, 16), with: .color(cream)); c.stroke(circle(x, ey, 16), with: .color(ink), lineWidth: 5)
                c.fill(circle(x, ey + 3, 7), with: .color(ink))
                let tilt: CGFloat = i == 1 ? 6 : -6
                c.stroke(line([CGPoint(x: x - 16, y: ey - 26 - tilt), CGPoint(x: x + 16, y: ey - 26 + tilt)]), with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            case 2:
                c.fill(circle(x, ey, 17), with: .color(cream)); c.stroke(circle(x, ey, 17), with: .color(ink), lineWidth: 5)
                var spiral = Path()
                let spin = t * 300 * .pi / 180
                for k in 0...60 {
                    let f = Double(k) / 60
                    let ang = f * 5 * .pi + spin
                    let r = 1 + f * 10
                    let pt = CGPoint(x: x + CGFloat(cos(ang) * r), y: ey + CGFloat(sin(ang) * r))
                    if k == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
                }
                c.stroke(spiral, with: .color(ink), lineWidth: 3.2)
            case 3:
                c.fill(circle(x, ey + 4, 15), with: .color(cream)); c.stroke(circle(x, ey + 4, 15), with: .color(ink), lineWidth: 5)
                c.fill(circle(x, ey + 9, 6), with: .color(ink))
                var lid = Path()
                lid.move(to: CGPoint(x: x - 16, y: ey + 1))
                lid.addQuadCurve(to: CGPoint(x: x + 16, y: ey + 1), control: CGPoint(x: x, y: ey - 20))
                lid.closeSubpath()
                c.fill(lid, with: .color(color))
                c.stroke(line([CGPoint(x: x - 17, y: ey + 2), CGPoint(x: x + 17, y: ey + 2)]), with: .color(ink), style: round)
            case 4:
                var shut = Path()
                shut.move(to: CGPoint(x: x - 15, y: ey + 2))
                shut.addQuadCurve(to: CGPoint(x: x + 15, y: ey + 2), control: CGPoint(x: x, y: ey - 12))
                c.stroke(shut, with: .color(ink), style: round)
                let k = CGFloat((t * 60).truncatingRemainder(dividingBy: 20))
                let dx: CGFloat = i == 1 ? 8 : -8
                var tearPath = Path()
                tearPath.move(to: CGPoint(x: x + dx, y: ey + 8))
                tearPath.addQuadCurve(to: CGPoint(x: x + dx, y: ey + 38 + k), control: CGPoint(x: x + dx + (i == 1 ? 4 : -4), y: ey + 26 + k))
                c.stroke(tearPath, with: .color(tear.opacity(0.9)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            default:
                var xs = Path()
                xs.move(to: CGPoint(x: x - 12, y: ey - 12)); xs.addLine(to: CGPoint(x: x + 12, y: ey + 12))
                xs.move(to: CGPoint(x: x + 12, y: ey - 12)); xs.addLine(to: CGPoint(x: x - 12, y: ey + 12))
                c.stroke(xs, with: .color(ink), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            }
        }

        // Mouth.
        let mx: CGFloat = 182, my: CGFloat = 200
        switch st {
        case 0:
            var m = Path()
            m.move(to: CGPoint(x: mx - 26, y: my - 6))
            m.addQuadCurve(to: CGPoint(x: mx + 26, y: my - 6), control: CGPoint(x: mx, y: my + 20))
            m.closeSubpath()
            c.fill(m, with: .color(ink)); c.stroke(m, with: .color(ink), style: round)
            var tongue = Path()
            tongue.move(to: CGPoint(x: mx - 12, y: my + 5))
            tongue.addQuadCurve(to: CGPoint(x: mx + 12, y: my + 5), control: CGPoint(x: mx, y: my + 13))
            c.fill(tongue, with: .color(tongueColor))
        case 1:
            var m = Path()
            m.move(to: CGPoint(x: mx - 24, y: my))
            m.addQuadCurve(to: CGPoint(x: mx - 8, y: my), control: CGPoint(x: mx - 16, y: my - 8))
            m.addQuadCurve(to: CGPoint(x: mx + 8, y: my), control: CGPoint(x: mx, y: my + 8))
            m.addQuadCurve(to: CGPoint(x: mx + 24, y: my), control: CGPoint(x: mx + 16, y: my - 8))
            c.stroke(m, with: .color(ink), style: round)
        case 2:
            c.fill(Path(ellipseIn: CGRect(x: mx - 11, y: my - 14, width: 22, height: 28)), with: .color(ink))
        case 3:
            c.stroke(line([CGPoint(x: mx - 22, y: my + 2), CGPoint(x: mx + 22, y: my + 2)]), with: .color(ink), style: round)
        case 4:
            var m = Path()
            m.move(to: CGPoint(x: mx - 26, y: my + 12))
            m.addQuadCurve(to: CGPoint(x: mx + 26, y: my + 12), control: CGPoint(x: mx, y: my - 14))
            m.closeSubpath()
            c.fill(m, with: .color(ink)); c.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineJoin: .round))
        default:
            c.stroke(line([CGPoint(x: mx - 24, y: my), CGPoint(x: mx + 24, y: my)]), with: .color(ink), style: round)
            var tongue = Path()
            tongue.move(to: CGPoint(x: mx + 2, y: my))
            tongue.addLine(to: CGPoint(x: mx + 2, y: my + 16))
            tongue.addQuadCurve(to: CGPoint(x: mx + 20, y: my + 16), control: CGPoint(x: mx + 11, y: my + 34))
            tongue.addLine(to: CGPoint(x: mx + 20, y: my))
            c.fill(tongue, with: .color(tongueColor))
            c.stroke(tongue, with: .color(ink), lineWidth: 5)
        }

        // Stem.
        c.stroke(line([CGPoint(x: 182, y: 268), CGPoint(x: 182, y: 294)]), with: .color(cream), style: StrokeStyle(lineWidth: 12, lineCap: .round))
    }

    private static var tongueColor: Color { tongue }
}
