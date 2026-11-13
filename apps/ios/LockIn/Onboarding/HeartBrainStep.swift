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
    /// One line per hours band, under the headline.
    private static let lines = [
        "A little more intentional time can go a long way.",
        "What would you do with a little of that time back?",
        "That\u{2019}s a lot of time. How much of it is really yours to choose?",
        "You don\u{2019}t have to change everything today. Start with 25 minutes."
    ]

    var body: some View {
        PrintScaffold(step: 5, grain: true, title: Self.titles[index],
                      titleSize: 46, primaryTitle: "CONTINUE", primaryAction: next) {
            VStack(alignment: .leading, spacing: 14) {
                Text(Self.lines[index])
                    .font(PrintFont.bold(18))
                    .foregroundStyle(Ink.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                monitor
                chips
                brainArea
                if !notesShown {
                    Text(status.uppercased())
                        .font(PrintFont.head(30))
                        .foregroundStyle(Ink.ink)
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
                    .foregroundStyle(on ? Color.white : Ink.ink.opacity(0.35))
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(on ? HeartArt.tiles[i].color : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(on ? Color.clear : Ink.ink.opacity(0.2), lineWidth: 2))
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
            status = hits == 1 ? HeartArt.lightDay : HeartArt.status[maxStage]
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
            status = HeartArt.lightDay
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

    private static let m30 = Note(tag: "30 MIN", text: "In a small study, students who limited social media to 30 minutes a day for 3 weeks reported feeling less lonely and less depressed.", source: "Hunt et al., U. of Pennsylvania, 2018")
    private static let mod = Note(tag: "1\u{2013}2H", text: "In a study of 120,000 UK teens, moderate use, around 1\u{2013}2 hours on weekdays, was not linked to lower well-being.", source: "Przybylski & Weinstein, Psychological Science, 2017")
    private static let h3 = Note(tag: "3H+", text: "Teens who used social media more than 3 hours a day were more likely to report anxiety or depression symptoms.", source: "Riehm et al., JAMA Psychiatry, 2019")
    private static let h6 = Note(tag: "6H+", text: "In the same study, the link was stronger for teens using social media more than 6 hours a day.", source: "Riehm et al., JAMA Psychiatry, 2019")
    private static let h7 = Note(tag: "7H+", text: "Teens with 7+ hours of daily screen time were about twice as likely as light users to have been diagnosed with anxiety or depression.", source: "Twenge & Campbell, Preventive Medicine Reports, 2018")
    private static let sleep = Note(tag: "SLEEP", text: "Most of the 67 studies in one review linked more screen time to later bedtimes or less sleep in kids and teens.", source: "Hale & Guan, Sleep Medicine Reviews, 2015")

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
            Text("These studies show links, not cause and effect. Not medical advice.")
                .font(PrintFont.mono(10, .regular))
                .foregroundStyle(HeartArt.bg.opacity(0.55))
                .padding(.top, 8)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white).shadow(color: .black.opacity(0.15), radius: 10, y: 6))
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
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white).shadow(color: .black.opacity(0.15), radius: 6, y: 4))
            .overlay(alignment: .bottomLeading) {
                Triangle().fill(Color.white).frame(width: 16, height: 12).offset(x: 22, y: 11)
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

/// Colors and words for this slide. The drawing itself lives in `BrainDrawing` (shared with the widget).
private enum HeartArt {
    static let bg = BrainDrawing.bg
    static let panel = BrainDrawing.panel
    static let grid = BrainDrawing.grid
    static let green = BrainDrawing.green
    static let alarm = BrainDrawing.alarm
    static let cream = BrainDrawing.cream
    static let bpmBase = BrainDrawing.bpmBase
    static let lines: [String?] = [nil, "just 1 more\u{2026}", "ok, 1 more\u{2026}", "12 more minutes\u{2026}", "wait, what was I doing?", nil]
    /// What the day feels like as the hours pile up. About attention and time, not health.
    static let status = ["Still in control.", "A little distracted.", "Pulled in a few directions.", "Hard to get back on track.", "Running on autopilot.", "Where did the day go?"]
    static let lightDay = "Nice. Keep it that way."
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

    static func bpmColor(_ stage: Int) -> Color { BrainDrawing.levelColor(stage) }

    static func ecg(stage: Int, t: Double, width: CGFloat) -> Path {
        BrainDrawing.ecg(stage: stage, t: t, width: width)
    }

    static func drawBrain(in ctx: inout GraphicsContext, stage: Int, t: Double) {
        BrainDrawing.drawBrain(in: &ctx, stage: stage, t: t)
    }
}
