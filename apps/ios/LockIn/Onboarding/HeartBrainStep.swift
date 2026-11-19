import SwiftUI

/// Slide 5: "your brain over one day". A sheet of chart paper; the brain is the pen and draws one
/// ink heart line across the day, 8 AM to 11 PM. Each app that pulls you in drops onto the line as
/// a sticker, and the beat gets faster and messier after it. The heart rate counts up, the time of
/// day runs, and it ends on one "you are here" finding. Mock: docs/design/heartbeat-v3.html.
/// It is a picture, not a diagnosis; the finding says "links, not cause".
struct HeartBrainStep: View {
    let hoursIndex: Int
    let next: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduce: Bool { effectiveReduceMotion(systemReduceMotion) }

    @State private var start = Date()
    @State private var hitCount = 0
    @State private var done = false

    private var band: Int { min(max(hoursIndex, 0), 3) }
    private var plan: DayPlan { DayPlan(band: band) }

    private static let titles = ["1\u{2013}2 hours\na day.", "3\u{2013}4 hours\na day.", "5\u{2013}6 hours\na day.", "7+ hours\na day."]
    private static let lines = [
        "A little more intentional time can go a long way.",
        "What would you do with a little of that time back?",
        "That\u{2019}s a lot of time. How much of it is really yours to choose?",
        "You don\u{2019}t have to change everything today. Start with 25 minutes."
    ]

    var body: some View {
        PrintScaffold(step: 5, title: Self.titles[band], titleSize: 46, grain: true,
                      primaryTitle: "CONTINUE", primaryAction: next) {
            VStack(alignment: .leading, spacing: 18) {
                Text(Self.lines[band])
                    .font(PrintFont.bold(17))
                    .foregroundStyle(Ink.ink.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                DayChart(plan: plan, start: start, reduce: reduce)
                    .frame(height: 284)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("A heart line across one day. It speeds up from \(DayPlan.bpm[0]) to \(DayPlan.bpm[plan.finalStage]) beats a minute as apps pull you in.")
                if done {
                    FindingCard(band: band)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    let stage = plan.stage(afterHits: hitCount)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(DayPlan.status[stage].uppercased())
                            .font(PrintFont.head(30))
                            .foregroundStyle(Ink.ink)
                            .contentTransition(.opacity)
                            .animation(.easeOut(duration: 0.25), value: stage)
                        Text("TIME ON PHONE \u{00B7} ") .font(PrintFont.mono(12, .semibold)).foregroundColor(Ink.ink.opacity(0.6))
                            + Text(DayPlan.clock(minutes: plan.minutes(afterHits: hitCount))).font(PrintFont.mono(12, .bold)).foregroundColor(Ink.ink)
                    }
                    .tracking(1.2)
                    .accessibilityElement(children: .combine)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: done)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hitCount)
        .task { await run() }
    }

    /// Steps the state the text and haptics need; the drawing itself runs off the clock.
    @MainActor
    private func run() async {
        start = Date()
        if reduce {
            hitCount = plan.hits
            done = true
            return
        }
        for i in 0..<plan.hits {
            let wait = plan.arrival(i) - Date().timeIntervalSince(start)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if Task.isCancelled { return }
            hitCount = i + 1
        }
        let wait = DayPlan.findAt - Date().timeIntervalSince(start)
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        if Task.isCancelled { return }
        done = true
    }
}

// MARK: - The day

/// Everything the slide shows, worked out from the hours band and the seconds since it started.
private struct DayPlan {
    let band: Int

    static let penStart: Double = 0.5
    static let penEnd: Double = 6.2
    static let findAt: Double = penEnd + 0.6
    static let bpm = [72, 86, 101, 117, 132, 146]
    /// About attention and time, not health.
    static let status = ["Still in control.", "A little distracted.", "Pulled in a few directions.",
                         "Hard to get back on track.", "Running on autopilot.", "Where did the day go?"]

    var hits: Int { [1, 2, 4, 5][band] }
    var finalStage: Int { [1, 2, 4, 5][band] }
    var hours: Double { [1.5, 3.5, 5.5, 7.5][band] }

    func stage(afterHits n: Int) -> Int {
        n == 0 ? 0 : Int((Double(n) * Double(finalStage) / Double(hits)).rounded())
    }

    func minutes(afterHits n: Int) -> Double { hours * 60 * Double(n) / Double(hits) }

    /// Where each app lands along the day, 0...1, a little uneven so it does not look like a grid.
    func spot(_ i: Int) -> Double {
        let even = hits == 1 ? 0.45 : Double(i) / Double(hits - 1)
        return 0.1 + 0.7 * even + (Self.noise(Double(i + band)) - 0.5) * 0.05
    }

    /// Seconds after the start when the pen reaches app `i`.
    func arrival(_ i: Int) -> Double { Self.penStart + (Self.penEnd - Self.penStart) * spot(i) }

    /// How far across the day the pen is, 0...1.
    static func progress(_ t: Double) -> Double { min(max((t - penStart) / (penEnd - penStart), 0), 1) }

    static func noise(_ i: Double) -> Double {
        let s = sin(i * 12.9898) * 43758.5453
        return s - floor(s)
    }

    static func clock(minutes: Double) -> String {
        let m = Int(minutes.rounded())
        return "\(m / 60)H \(String(format: "%02d", m % 60))M"
    }

    static func timeOfDay(_ progress: Double) -> String {
        let minutes = 8 * 60 + progress * 15 * 60
        let h = Int(minutes) / 60, m = Int(minutes) % 60
        return "\((h + 11) % 12 + 1):\(String(format: "%02d", m)) \(h >= 12 ? "PM" : "AM")"
    }
}

// MARK: - Chart

private struct DayChart: View {
    let plan: DayPlan
    let start: Date
    let reduce: Bool

    private static let top: CGFloat = 84, bottom: CGFloat = 248, mid: CGFloat = 196, inset: CGFloat = 18
    private static let tiles: [(symbol: String, fill: Color, glyph: Color)] = [
        ("play.fill", Color(hex: 0xE5484D), .white), ("bubble.left.fill", Ink.blue, .white),
        ("music.note", Ink.sun, Ink.ink), ("envelope", Ink.ink, .white), ("heart.fill", Color(hex: 0xE8578E), .white)
    ]

    var body: some View {
        TimelineView(.animation(paused: reduce)) { context in
            let t = reduce ? 60 : context.date.timeIntervalSince(start)
            GeometryReader { g in
                let w = g.size.width
                let x0 = Self.inset, x1 = w - Self.inset
                let p = DayPlan.progress(t)
                let penX = x0 + (x1 - x0) * p
                let spots = (0..<plan.hits).map { x0 + (x1 - x0) * plan.spot($0) }
                let passed = spots.filter { $0 <= penX }.count
                let stage = plan.stage(afterHits: passed)
                let stageAt: (CGFloat) -> Int = { x in plan.stage(afterHits: spots.filter { $0 <= x }.count) }

                ZStack(alignment: .topLeading) {
                    Canvas { ctx, size in
                        drawPaper(&ctx, x0: x0, x1: x1)
                        var future = Path()
                        future.move(to: CGPoint(x: penX, y: Self.mid))
                        future.addLine(to: CGPoint(x: x1, y: Self.mid))
                        ctx.stroke(future, with: .color(Ink.ink.opacity(0.25)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
                        let line = Self.trace(from: x0, to: penX, stageAt: stageAt)
                        let style = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        ctx.stroke(line.offsetBy(dx: 2.5, dy: 2), with: .color(Ink.blue.opacity(0.85)), style: style)
                        ctx.stroke(line, with: .color(Ink.ink), style: style)
                    }

                    header(stage: stage, t: t, progress: p)

                    ForEach(0..<plan.hits, id: \.self) { i in
                        sticker(i, x: spots[i], t: t)
                    }

                    pen(x: penX, w: w, stage: stage, t: t, spots: spots, stageAt: stageAt)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: 0xF4F4F0)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Ink.ink, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Ink.ink).offset(y: 5))
    }

    /// EKG paper in riso blue, with the hours along the bottom.
    private func drawPaper(_ ctx: inout GraphicsContext, x0: CGFloat, x1: CGFloat) {
        var thin = Path(), thick = Path()
        var i = 0
        var x = x0
        while x <= x1 + 0.5 {
            var p = Path(); p.move(to: CGPoint(x: x, y: Self.top)); p.addLine(to: CGPoint(x: x, y: Self.bottom))
            if i % 5 == 0 { thick.addPath(p) } else { thin.addPath(p) }
            x += (x1 - x0) / 30; i += 1
        }
        i = 0
        var y = Self.top
        while y <= Self.bottom + 0.5 {
            var p = Path(); p.move(to: CGPoint(x: x0, y: y)); p.addLine(to: CGPoint(x: x1, y: y))
            if i % 5 == 0 { thick.addPath(p) } else { thin.addPath(p) }
            y += (Self.bottom - Self.top) / 15; i += 1
        }
        ctx.stroke(thin, with: .color(Ink.blue.opacity(0.08)), lineWidth: 1)
        ctx.stroke(thick, with: .color(Ink.blue.opacity(0.2)), lineWidth: 1)
        let labels: [(String, Double)] = [("8AM", 0), ("12PM", 0.27), ("4PM", 0.53), ("8PM", 0.8), ("11PM", 1)]
        for (n, (label, f)) in labels.enumerated() {
            let lx = x0 + (x1 - x0) * f + (n == 0 ? 10 : n == labels.count - 1 ? -12 : 0)
            ctx.draw(Text(label).font(PrintFont.mono(9.5, .semibold)).foregroundColor(Ink.ink.opacity(0.6)),
                     at: CGPoint(x: lx, y: Self.bottom + 15))
        }
    }

    /// The heart line: calm beats early, each app makes the next ones faster, taller and less even.
    static func y(at x: CGFloat, x0: CGFloat, stageAt: (CGFloat) -> Int) -> CGFloat {
        let st = stageAt(x)
        let period: CGFloat = [44, 36, 29, 24, 20, 17][st]
        let amp: CGFloat = [30, 32, 34, 36, 38, 38][st]
        let pos = (x - x0) / period
        let k = floor(pos), ph = pos - k
        let jitter: CGFloat = st >= 3 ? CGFloat(DayPlan.noise(Double(k) + 3) - 0.5) * 0.5 : 0
        let skipped = st >= 4 && DayPlan.noise(Double(k) * 7.1) < 0.18
        let a = skipped ? amp * 0.25 : amp * (1 + jitter)
        var v: CGFloat = 0
        if ph > 0.12 && ph < 0.24 { v -= sin((ph - 0.12) / 0.12 * .pi) * 3 }
        if ph > 0.32 && ph < 0.37 { v += (ph - 0.32) / 0.05 * 5 }
        else if ph >= 0.37 && ph < 0.42 { v += 5 - (ph - 0.37) / 0.05 * (a + 5) }
        else if ph >= 0.42 && ph < 0.47 { v += -a + (ph - 0.42) / 0.05 * (a * 1.35) }
        else if ph >= 0.47 && ph < 0.52 { v += a * 0.35 - (ph - 0.47) / 0.05 * (a * 0.35) }
        if ph > 0.62 && ph < 0.8 { v -= sin((ph - 0.62) / 0.18 * .pi) * 6 }
        let wander: CGFloat = st >= 3 ? sin(x * 0.045) * CGFloat(st - 2) * 3 : 0
        return mid - v + wander
    }

    static func trace(from x0: CGFloat, to x1: CGFloat, stageAt: (CGFloat) -> Int) -> Path {
        var p = Path()
        var x = x0
        p.move(to: CGPoint(x: x, y: y(at: x, x0: x0, stageAt: stageAt)))
        while x < x1 {
            x = min(x + 0.75, x1)
            p.addLine(to: CGPoint(x: x, y: y(at: x, x0: x0, stageAt: stageAt)))
        }
        return p
    }

    private func header(stage: Int, t: Double, progress: Double) -> some View {
        let bpm = DayPlan.bpm[stage]
        let beat = (t * Double(bpm) / 60).truncatingRemainder(dividingBy: 1)
        let pulse = reduce ? 1 : 1 + 0.22 * exp(-beat * 9)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HEART RATE").font(PrintFont.mono(10, .bold)).tracking(1.6).foregroundStyle(Ink.ink.opacity(0.6))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(bpm)").font(PrintFont.head(48)).monospacedDigit().foregroundStyle(Ink.ink)
                        .contentTransition(.numericText(value: Double(bpm)))
                        .animation(.snappy, value: bpm)
                    Text("BPM").font(PrintFont.mono(12, .bold)).foregroundStyle(Ink.ink)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(Ink.blue)
                        .scaleEffect(pulse)
                        .padding(.leading, 6)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text("TIME OF DAY").font(PrintFont.mono(10, .bold)).tracking(1.6).foregroundStyle(Ink.ink.opacity(0.6))
                Text(DayPlan.timeOfDay(progress)).font(PrintFont.mono(18, .bold)).monospacedDigit().foregroundStyle(Ink.ink)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    /// An app tile that drops onto the line just before the pen reaches it, then squishes.
    private func sticker(_ i: Int, x: CGFloat, t: Double) -> some View {
        let tile = Self.tiles[i % Self.tiles.count]
        let arrive = plan.arrival(i)
        let k = min(max((t - (arrive - 0.45)) / 0.45, 0), 1)
        let eased = 1 - pow(1 - k, 3)
        let land = Self.mid - 84
        let y = -60 + (land + 60) * CGFloat(eased)
        let since = t - arrive
        let squish = since >= 0 ? 1 + 0.25 * exp(-since * 10) * cos(since * 30) : 1
        return Image(systemName: tile.symbol)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(tile.glyph)
            .frame(width: 38, height: 38)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tile.fill))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Ink.ink, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Ink.ink).offset(y: 3))
            .scaleEffect(x: 1 / squish, y: squish, anchor: .bottom)
            .rotationEffect(.degrees((i % 2 == 0 ? -8 : 9) * eased))
            .opacity(k > 0 ? 1 : 0)
            .position(x: x, y: y + 19)
    }

    /// The brain rides the tip of the line, bobbing, with a squash when an app lands.
    private func pen(x: CGFloat, w: CGFloat, stage: Int, t: Double, spots: [CGFloat], stageAt: (CGFloat) -> Int) -> some View {
        let lineY = Self.y(at: max(Self.inset, x - 1), x0: Self.inset, stageAt: stageAt)
        let since = (0..<plan.hits).map { t - plan.arrival($0) }.filter { $0 >= 0 }.min() ?? 9
        let squash = reduce ? 0 : 0.18 * exp(-since * 7) * cos(since * 22)
        let bob: CGFloat = reduce ? 0 : CGFloat(sin(t * 5) * 1.5)
        // The last stage of the old art reads as hurt; the pen stays at "frazzled" at worst.
        let drawn = min(stage, 4)
        return Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 364, y: size.height / 300)
            BrainDrawing.drawBrain(in: &ctx, stage: drawn, t: t)
        }
        .frame(width: 84, height: 69)
        .scaleEffect(x: 1 + squash, y: 1 - squash, anchor: .bottom)
        .position(x: min(x, w - 32), y: lineY - 34 + bob)
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
