import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

// The printed first-run slides. Each one is a different paper object in the same inks.
// Layout follows docs/design/ob-v2.html; every slide scrolls, so small phones keep the buttons.

private let hoursTabs = ["1\u{2013}2 HRS", "3\u{2013}4 HRS", "5\u{2013}6 HRS", "7+ HRS"]

// MARK: 1. Hook

struct HookStep: View {
    /// The longer introduction (optional).
    let next: () -> Void
    /// The short way: straight to the Focus screen, where the coach takes over.
    let startNow: () -> Void
    @State private var number = "?H ??M"
    @State private var noteShown = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        PrintScaffold(step: 1, tag: "Your phone time", title: "Where does\nthe time go?", titleSize: 58, grain: true,
                      primaryTitle: "LET\u{2019}S FIND OUT", primaryAction: next,
                      secondaryTitle: "Skip intro", secondaryAction: startNow) {
            VStack(alignment: .leading, spacing: 6) {
                Text(number)
                    .font(PrintFont.head(GuessStep.compact ? 100 : 128))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Ink.ink)
                    .monospacedDigit()
                    .misprint()
                    .accessibilityLabel("Unknown hours a day")
                Text("Let\u{2019}s find out.")
                    .font(PrintFont.mono(14))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top) {
                    Spacer()
                    ZStack(alignment: .bottomTrailing) {
                        HookArrow()
                            .trim(from: 0, to: noteShown ? 1 : 0)
                            .stroke(Ink.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            .frame(width: 110, height: 84)
                        Text("you?")
                            .font(PrintFont.hand(34))
                            .foregroundStyle(Ink.blue)
                            .rotationEffect(.degrees(-6))
                            .offset(x: 36, y: 34)
                            .scaleEffect(noteShown ? 1 : 0.3)
                            .opacity(noteShown ? 1 : 0)
                    }
                    .padding(.trailing, 40)
                }
                .frame(height: 120)
                .accessibilityHidden(true)
            }
        }
        .task {
            if effectiveReduceMotion(systemReduceMotion) { noteShown = true; return }
            guard await printPause(0.3) else { return }
            for _ in 0..<14 {
                number = "\(Int.random(in: 1...9))H \(String(format: "%02d", Int.random(in: 0...59)))M"
                guard await printPause(0.09) else { return }
            }
            number = "?H ??M"
            guard await printPause(0.3) else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { noteShown = true }
        }
    }
}

/// A hand-drawn arrow from the "you?" note up to the number.
private struct HookArrow: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX - 14, y: r.maxY - 4))
        p.addCurve(to: CGPoint(x: r.minX + 14, y: r.minY + 14),
                   control1: CGPoint(x: r.maxX - 30, y: r.minY + 40),
                   control2: CGPoint(x: r.minX + 50, y: r.minY + 20))
        p.move(to: CGPoint(x: r.minX + 30, y: r.minY + 2))
        p.addLine(to: CGPoint(x: r.minX + 12, y: r.minY + 14))
        p.addLine(to: CGPoint(x: r.minX + 28, y: r.minY + 28))
        return p
    }
}

// MARK: 2. Guess

/// A "lost" poster. The user tears off the tab that matches their guess.
struct GuessStep: View {
    /// iPhone SE and other short screens: a smaller poster so the tabs are above the fold.
    static var compact: Bool { UIScreen.main.bounds.height < 700 }
    @Binding var guessIndex: Int?
    let next: () -> Void

    var body: some View {
        PrintScaffold(step: 2, tag: "Your phone time", title: "How many hours\na day?", titleSize: 46, grain: true,
                      primaryTitle: "SEE MY ACTUAL TIME", primaryEnabled: guessIndex != nil, primaryAction: next,
                      secondaryTitle: "Skip", secondaryAction: { guessIndex = nil; next() }) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Guess first. iPhone will ask to share your real number next.")
                    .font(PrintFont.mono(14))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                poster
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.6), value: guessIndex)
        }
    }

    private var poster: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LOST:\nA FEW HOURS")
                .font(PrintFont.head(Self.compact ? 52 : 76))
                .misprint(Ink.sun)
                .lineSpacing(-14)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                // Room on the right for the torn-off tab, which sits over the poster's corner.
                .padding(.trailing, 64)
                .foregroundStyle(Ink.orange)
                .padding(.horizontal, 18)
                .padding(.top, 18)
            Text("Last seen: \u{201C}Just one more video.\u{201D}")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 16)
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    tab(i)
                    if i < 3 { DashedLine(vertical: true).frame(width: 2) }
                }
            }
            .frame(height: Self.compact ? 112 : 150)
            .overlay(alignment: .top) { DashedLine(vertical: false).frame(height: 2) }
        }
        .background(Color.white)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 10)
        .rotationEffect(.degrees(1.2))
        .overlay(alignment: .topTrailing) {
            if let guessIndex {
                looseTab(guessIndex)
                    .offset(x: 6, y: 10)
                    .transition(.asymmetric(insertion: .offset(x: -80, y: 260).combined(with: .opacity), removal: .opacity))
            }
        }
    }

    private func tab(_ i: Int) -> some View {
        let torn = guessIndex == i
        return Button { guessIndex = i } label: {
            ZStack {
                (torn ? Ink.paper : Color.white)
                if !torn {
                    Text(hoursTabs[i])
                        .font(PrintFont.head(28))
                        .foregroundStyle(Ink.ink)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: torn)
        .accessibilityLabel(hoursTabs[i].replacingOccurrences(of: "HRS", with: "hours"))
        .accessibilityAddTraits(torn ? .isSelected : [])
    }

    private func looseTab(_ i: Int) -> some View {
        Text(hoursTabs[i])
            .font(PrintFont.head(28))
            .foregroundStyle(Ink.orange)
            .fixedSize()
            .rotationEffect(.degrees(-90))
            .frame(width: 72, height: 128)
            .background(Color.white)
            .overlay(alignment: .top) {
                Rectangle().fill(Ink.orange.opacity(0.65)).frame(width: 64, height: 22)
                    .rotationEffect(.degrees(6)).offset(y: -10)
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 8)
            .rotationEffect(.degrees(9))
            .accessibilityHidden(true)
    }
}

/// The dashed cut line between poster tabs.
private struct DashedLine: View {
    let vertical: Bool

    var body: some View {
        GeometryReader { g in
            Path { p in
                p.move(to: .zero)
                p.addLine(to: vertical ? CGPoint(x: 0, y: g.size.height) : CGPoint(x: g.size.width, y: 0))
            }
            .stroke(Ink.ink.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        }
    }
}

// MARK: 4. Real hours

/// The real numbers, drawn by Apple's report view inside the LockInReport extension. Lock In
/// cannot read them. The report starts loading at once, under a "reading your week" cover whose
/// loading bar runs through the seven days; then the cover lifts off (mock: docs/design/reveal-load.html).
/// If the report still isn't drawn then, a small spinner shows instead of a blank slide.
struct RevealStep: View {
    let guessIndex: Int?
    let next: () -> Void
    @State private var showReport = false
    @State private var mountReport = false
    @State private var lifted = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    /// Room for the report: its stamp hangs below the receipt, over the "days a year" line's gap.
    private static let height: CGFloat = 574

    var body: some View {
        // No grain here: the cover below is flat paper, and grain would show its edges.
        PrintScaffold(step: 3, tag: "Your phone time", tagColor: OutlinedText.orangeDeep,
                      primaryTitle: "NEXT", primaryEnabled: showReport, primaryAction: next) {
            ZStack(alignment: .top) {
                // Only seen if Apple's report is still drawing when the cover lifts.
                VStack(spacing: 14) {
                    ProgressView().tint(Ink.ink)
                    Text("Adding up your week\u{2026}")
                        .font(PrintFont.mono(13, .bold))
                        .foregroundStyle(Ink.ink.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 200)
                // Mounted early, under the cover, so the extension reads the week while "reading your
                // week" plays (it used to start only after it, adding its whole load time on top).
                // Not at once: coming Back from slide 5, its report is still on screen during the
                // slide transition, and two reports at once can draw each other's content.
                if mountReport {
                    DeviceActivityReport(.reveal(guess: guessIndex), filter: ScreenTimeReport.lastWeek)
                        .frame(height: Self.height)
                        .frame(maxWidth: .infinity)
                }
                GuessCheck(guessIndex: guessIndex)
                    .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .topLeading)
                    .background(Ink.paper)
                    .coverLift(lifted, reduceMotion: effectiveReduceMotion(systemReduceMotion))
                    .allowsHitTesting(!showReport)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: showReport)
        .task {
            // Slide transitions settle in about a second; wait them out so only one report is up.
            guard await printPause(1.0) else { return }
            mountReport = true
            // The cover's loading bar finishes about 3.9 s in; lift it just after.
            let still = effectiveReduceMotion(systemReduceMotion)
            guard await printPause(still ? 0.2 : 3.4) else { return }
            withAnimation(still ? .easeOut(duration: 0.3) : .coverLift) { lifted = true }
            showReport = true
        }
    }
}

/// The cover on slide 3 while Apple's report loads, so the slide is never blank (mock:
/// docs/design/reveal-load.html): "Let's check your guess." The guess tab from slide 2 is taped up,
/// the brain looks at it through a magnifying glass, and a loading bar reads the week one day at a
/// time: each day's segment fills, then that day's bar turns solid and its "?" becomes a tick.
/// Without a guess it reads "Reading your week…" and shows only the bars.
private struct GuessCheck: View {
    let guessIndex: Int?
    /// Bars risen so far (they all come up in the first half second).
    @State private var days = 0
    /// The loading bar segment that is filling (or full), and how many days are done.
    @State private var filling = -1
    @State private var loaded = 0
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]
    /// Made-up heights: the bars are a "reading" animation, not data.
    private static let heights: [CGFloat] = [0.62, 0.48, 0.70, 0.55, 0.80, 0.92, 0.74]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(guessIndex == nil ? "READING\nYOUR WEEK\u{2026}" : "LET\u{2019}S CHECK\nYOUR GUESS.")
                .font(PrintFont.head(52))
                .lineSpacing(-6)
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let guessIndex {
                HStack(alignment: .center, spacing: 0) {
                    tab(guessIndex)
                        .rotationEffect(.degrees(-5))
                    Spacer(minLength: 8)
                    ZStack(alignment: .bottomLeading) {
                        Image("BrainExact").resizable().scaledToFit().frame(width: 100)
                            .rotationEffect(.degrees(bob ? 4 : -4))
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(Ink.ink)
                            .offset(x: bob ? -30 : -14, y: bob ? 6 : -4)
                    }
                    .padding(.trailing, 8)
                }
                .overlay(alignment: .bottomTrailing) {
                    Stamp(text: "Checking\u{2026}", color: Ink.red, size: 20, tilt: 8)
                        .offset(x: -4, y: 22)
                }
                .padding(.bottom, 8)
            }
            week
            loader
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(guessIndex == nil ? "Reading your week" : "Checking your guess against your real week")
        .accessibilityValue("\(percent) percent")
        .sensoryFeedback(.selection, trigger: loaded)
        .task {
            if effectiveReduceMotion(systemReduceMotion) { days = 7; filling = 6; loaded = 7; return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { bob = true }
            for i in 1...7 {
                guard await printPause(0.07) else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { days = i }
            }
            guard await printPause(0.2) else { return }
            // About 3.2 s for the week; RevealStep lifts the cover right after the last day.
            for i in 0..<7 {
                withAnimation(.timingCurve(0.77, 0, 0.175, 1, duration: 0.42)) { filling = i }
                guard await printPause(0.46) else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { loaded = i + 1 }
            }
        }
    }

    private var percent: Int { Int((Double(loaded) / 7 * 100).rounded()) }

    private func tab(_ g: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOU GUESSED").font(PrintFont.mono(10, .bold)).tracking(1.4)
                .foregroundStyle(Ink.ink.opacity(0.7))
            OutlinedText(text: hoursTabs[min(max(g, 0), 3)], font: PrintFont.head(40), ink: Ink.ink, outline: 1.5, drop: 3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("A DAY").font(PrintFont.mono(11, .bold)).tracking(1.2)
                .foregroundStyle(Ink.ink.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(width: 176, alignment: .leading)
        // Same paper as the slide; the ink edge and drop keep it a separate card.
        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.paper))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.ink, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 12).fill(Ink.ink).offset(y: 6))
        .overlay(alignment: .top) {
            MaskingTape().rotationEffect(.degrees(-3)).offset(y: -14)
        }
    }

    private var week: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(spacing: 6) {
            HStack {
                Text("YOUR WEEK")
                Spacer()
                Text(loaded >= 7 ? "DONE" : "\(loaded) / 7")
                    .foregroundStyle(Ink.blue)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .font(PrintFont.mono(10.5, .bold)).tracking(1.2)
            .foregroundStyle(Color(hex: 0x45473F))
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    let on = i < days
                    let done = i < loaded
                    VStack(spacing: 4) {
                        ZStack {
                            Text("?").font(PrintFont.head(16)).foregroundStyle(Ink.blue).opacity(on && !done ? 1 : 0)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Ink.ink))
                                .scaleEffect(done ? 1 : 0.4)
                                .opacity(done ? 1 : 0)
                        }
                        UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                            .fill(Ink.blue.opacity(done ? 1 : 0.55))
                            .overlay(UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                                .strokeBorder(Ink.ink, lineWidth: 2))
                            .frame(height: on ? 86 * Self.heights[i] : 0)
                            // A little hop as the day comes in.
                            .keyframeAnimator(initialValue: CGFloat(1), trigger: done) { bar, s in
                                bar.scaleEffect(y: s, anchor: .bottom)
                            } keyframes: { _ in
                                KeyframeTrack {
                                    CubicKeyframe(1.08, duration: 0.12)
                                    SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 112, alignment: .bottom)
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2) }
            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Self.letters[i]).font(PrintFont.mono(10.5, .bold)).foregroundStyle(Color(hex: 0x45473F))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(shape.fill(Color(hex: 0xF4F4F0)))
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 5))
    }

    /// Seven segments, one per day, under the chart: the segment fills, then its day is done.
    private var loader: some View {
        let seg = RoundedRectangle(cornerRadius: 6, style: .continuous)
        let box = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(loaded >= 7 ? "YOUR WEEK IS IN" : "READING YOUR WEEK")
                    .foregroundStyle(Ink.blue)
                    .contentTransition(.opacity)
                Spacer()
                Text("\(percent)%")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(percent)))
            }
            .font(PrintFont.mono(11, .bold)).tracking(1.4)
            .foregroundStyle(Ink.ink)
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { i in
                    ZStack {
                        seg.fill(Ink.ink.opacity(0.07))
                        seg.fill(Ink.blue).scaleEffect(x: i <= filling ? 1 : 0.001, anchor: .leading)
                        Text(Self.letters[i])
                            .font(PrintFont.mono(11, .bold))
                            .foregroundStyle(i < loaded ? Color.white : Ink.ink.opacity(0.35))
                    }
                    .clipShape(seg)
                }
            }
            .padding(4)
            .frame(height: 42)
            .background(box.fill(Color.white))
            .overlay(box.strokeBorder(Ink.ink, lineWidth: 2))
            .background(box.fill(Ink.ink).offset(y: 4))
            .padding(.top, 9)
            Text(loaded >= 7 ? "Got it. Here\u{2019}s your number."
                 : filling < 0 ? "Opening Screen Time\u{2026}" : "Reading \(Self.names[filling])\u{2026}")
                .font(PrintFont.body(15, .heavy))
                .foregroundStyle(Ink.ink)
                .contentTransition(.opacity)
                .padding(.top, 14)
        }
    }
}

/// A strip of cream masking tape: a little see-through, torn zig-zag ends, two creases.
private struct MaskingTape: View {
    var width: CGFloat = 94
    private let height: CGFloat = 26

    var body: some View {
        ZStack {
            TornStrip().fill(LinearGradient(colors: [Color(hex: 0xF1E7C9), Color(hex: 0xE2D3AC)],
                                            startPoint: .top, endPoint: .bottom))
            // Paper fibre, then the creases where it was pressed down.
            Canvas { context, size in
                var fibre = Path()
                var x: CGFloat = 3
                while x < size.width { fibre.move(to: CGPoint(x: x, y: 0)); fibre.addLine(to: CGPoint(x: x + 1, y: size.height)); x += 4 }
                context.stroke(fibre, with: .color(.white.opacity(0.18)), lineWidth: 1)
                let creases: [(CGFloat, CGFloat, Color)] = [(0.31, 0.37, Color.white.opacity(0.6)),
                                                            (0.32, 0.38, Color(hex: 0x8A7A50).opacity(0.25)),
                                                            (0.71, 0.67, Color.white.opacity(0.45))]
                for (a, b, color) in creases {
                    var crease = Path()
                    crease.move(to: CGPoint(x: size.width * a, y: 2))
                    crease.addLine(to: CGPoint(x: size.width * b, y: size.height - 2))
                    context.stroke(crease, with: .color(color), lineWidth: 1.1)
                }
            }
            .clipShape(TornStrip())
        }
        .frame(width: width, height: height)
        .opacity(0.93)
        .compositingGroup()
        .shadow(color: Ink.ink.opacity(0.26), radius: 1.3, y: 1.5)
        .accessibilityHidden(true)
    }

    /// A strip with uneven zig-zag ends, the way tape tears off the roll.
    private struct TornStrip: Shape {
        func path(in r: CGRect) -> Path {
            let left: [CGFloat] = [0.04, 0.0, 0.05, 0.01, 0.05, 0.0]
            let right: [CGFloat] = [0.97, 1.0, 0.96, 1.0, 0.95, 0.99]
            var p = Path()
            p.move(to: CGPoint(x: r.minX + r.width * 0.03, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.02, y: r.minY))
            for (i, x) in right.enumerated() {
                p.addLine(to: CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * CGFloat(i + 1) / 7))
            }
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.03, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + r.width * 0.02, y: r.maxY))
            for (i, x) in left.enumerated().reversed() {
                p.addLine(to: CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * CGFloat(i + 1) / 7))
            }
            p.closeSubpath()
            return p
        }
    }
}

/// Whether this build carries the report extension. Without it the reveal slide is skipped.
enum ScreenTimeReport {
    /// The last 7 days, one segment per day, this iPhone only.
    static var lastWeek: DeviceActivityFilter {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfDay(for: end)) ?? end
        return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: end)),
                                    users: .all, devices: .init([.iPhone]))
    }

    static var isAvailable: Bool {
        // The report extension is an ExtensionKit extension: it lives in Extensions/, not PlugIns/.
        let url = Bundle.main.bundleURL.appendingPathComponent("Extensions")
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return false }
        return items.contains("LockInReport.appex")
    }
}

// MARK: 9. What pulls you in

/// A printed checklist of the kinds of apps that keep people longer than they planned, each with
/// real examples (names only, no logos). Tapping a row checks its box and a sunflower highlighter
/// swipes under the name; the brain reacts to how many you pick. Mock: docs/design/pulls-v2.html.
struct PullsStep: View {
    @Binding var categories: Set<String>
    let next: () -> Void
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private struct Kind {
        let name: String
        let examples: String
        let symbol: String
        let color: Color
        let glyph: Color
    }

    /// The names are what the plan and `OnboardingStore` keep, so they stay as they were.
    private static let kinds: [Kind] = [
        Kind(name: "Video", examples: "YouTube, TikTok, streaming", symbol: "play.fill", color: Ink.blue, glyph: .white),
        Kind(name: "Social", examples: "Instagram, Snapchat, X, Reddit", symbol: "person.2.fill", color: Ink.red, glyph: .white),
        Kind(name: "Games", examples: "Just one more round", symbol: "gamecontroller.fill", color: Ink.sun, glyph: Ink.ink),
        Kind(name: "Chat", examples: "Group chats, Discord", symbol: "bubble.left.and.bubble.right.fill", color: Ink.ink, glyph: .white),
        Kind(name: "Shopping", examples: "Scrolling deals and carts", symbol: "bag.fill", color: Ink.blue, glyph: .white),
        Kind(name: "News", examples: "Headlines, sports scores", symbol: "newspaper.fill", color: Ink.red, glyph: .white)
    ]
    private static let reactions = ["Be honest.", "Same here.", "Classic combo.", "Big ones. Got it."]
    private static let exampleInk = Color(hex: 0x3F413B)

    private var reduceMotion: Bool { effectiveReduceMotion(systemReduceMotion) }
    private var compact: Bool { UIScreen.main.bounds.height < 700 }

    var body: some View {
        // The headline is drawn here (not by the scaffold) so the brain can sit beside it.
        PrintScaffold(step: 7, tag: "Make it yours", grain: true,
                      primaryTitle: "NEXT", primaryEnabled: !categories.isEmpty, primaryAction: next,
                      secondaryTitle: "Skip", secondaryAction: next) {
            header
            Text("Tap what keeps you scrolling. It shapes your plan.")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            sheet
        }
        .task {
            if reduceMotion { shown = Self.kinds.count; return }
            for i in 1...Self.kinds.count {
                guard await printPause(0.07) else { return }
                withAnimation(.easeOut(duration: 0.3)) { shown = i }
            }
        }
    }

    private var header: some View {
        let size: CGFloat = compact ? 52 * 0.8 : 52
        return ZStack(alignment: .topTrailing) {
            Text("WHAT PULLS\nYOU IN?")
                .font(PrintFont.head(size))
                .lineSpacing(-size * 0.12)
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("What pulls you in?")
            VStack(alignment: .trailing, spacing: 4) {
                Image("BrainExact")
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 70 : 88)
                    .keyframeAnimator(initialValue: Hop(), trigger: reduceMotion ? 0 : categories.count) { view, v in
                        view.offset(y: v.y).rotationEffect(.degrees(v.r))
                    } keyframes: { _ in
                        KeyframeTrack(\.y) { CubicKeyframe(-12, duration: 0.16); SpringKeyframe(0, duration: 0.4) }
                        KeyframeTrack(\.r) { CubicKeyframe(6, duration: 0.16); SpringKeyframe(0, duration: 0.4) }
                    }
                ZStack(alignment: .trailing) {
                    let line = Self.reactions[min(categories.count, Self.reactions.count - 1)]
                    Text(line)
                        .font(PrintFont.bold(15))
                        .foregroundStyle(Ink.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        // White right behind the words, the ink shadow behind that (the other way
                        // round the ink covered the white and hid the words).
                        .background(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14,
                                                           bottomTrailingRadius: 14, topTrailingRadius: 4).fill(Color.white))
                        .background(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14,
                                                           bottomTrailingRadius: 14, topTrailingRadius: 4).fill(Ink.ink).offset(y: 3))
                        .overlay(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14,
                                                        bottomTrailingRadius: 14, topTrailingRadius: 4).strokeBorder(Ink.ink, lineWidth: 2))
                        .id(line)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.8, anchor: .topTrailing).combined(with: .opacity))
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: categories.count)
            }
            .accessibilityHidden(true)
        }
        // Tall enough for the brain and its bubble, which reach below the two-line headline;
        // without this the bubble spilled under the line of text after it and was covered.
        .frame(minHeight: compact ? 116 : 136, alignment: .top)
    }

    private var sheet: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(spacing: 0) {
            ForEach(Array(Self.kinds.enumerated()), id: \.offset) { i, kind in
                if i > 0 {
                    DashLine()
                        .stroke(Ink.ink.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .frame(height: 1.5)
                }
                row(kind)
                    .opacity(shown > i ? 1 : 0)
                    .offset(y: shown > i ? 0 : 12)
            }
        }
        .background(shape.fill(Ink.notebook))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 5))
        .padding(.horizontal, -4)
        .padding(.bottom, 6)
    }

    private func row(_ kind: Kind) -> some View {
        let on = categories.contains(kind.name)
        return Button {
            if on { categories.remove(kind.name) } else { categories.insert(kind.name) }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(kind.glyph)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(kind.color))
                    .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
                    .keyframeAnimator(initialValue: Hop(), trigger: reduceMotion ? false : on) { view, v in
                        view.offset(y: v.y).rotationEffect(.degrees(v.r))
                    } keyframes: { _ in
                        KeyframeTrack(\.y) { CubicKeyframe(-6, duration: 0.15); SpringKeyframe(0, duration: 0.3) }
                        KeyframeTrack(\.r) { CubicKeyframe(-10, duration: 0.15); SpringKeyframe(0, duration: 0.3) }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.name)
                        .font(PrintFont.bold(19))
                        .foregroundStyle(Ink.ink)
                        .background(alignment: .leading) {
                            // The highlighter: a sunflower stroke behind the lower half of the name.
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Ink.sun)
                                .frame(height: 11)
                                .padding(.leading, -3)
                                .padding(.trailing, -5)
                                .offset(y: 4)
                                .scaleEffect(x: on ? 1 : 0.001, anchor: .leading)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.05), value: on)
                        }
                    Text(kind.examples)
                        .font(PrintFont.body(13, .medium))
                        .foregroundStyle(Self.exampleInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 8)
                checkbox(on)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.name)
        .accessibilityHint(kind.examples)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func checkbox(_ on: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Ink.blue)
                .scaleEffect(on ? 1 : 0.001)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: on)
            CheckMark()
                .trim(from: 0, to: on ? 1 : 0)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .frame(width: 14, height: 14)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25).delay(0.1), value: on)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Ink.ink, lineWidth: 2)
        }
        .frame(width: 28, height: 28)
    }
}

private struct Hop {
    var y: CGFloat = 0
    var r: Double = 0
}

private struct DashLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

private struct CheckMark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.52))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.minY + r.height * 0.84))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.04, y: r.minY + r.height * 0.14))
        return p
    }
}

// MARK: 7. Lock the apps

/// Screen Time's own app picker. If access was skipped earlier, this asks again ("Continue").
struct LockAppsStep: View {
    @ObservedObject var restrictions: RestrictionController
    let next: () -> Void
    @State private var picking = false
    @Environment(\.openURL) private var openURL

    private var lockedCount: Int {
        restrictions.selection.applicationTokens.count + restrictions.selection.categoryTokens.count
    }

    var body: some View {
        let has = restrictions.hasSelection
        // No session runs during the first run, so the apps are picked, not locked yet.
        let words = LockWords(chosen: has ? lockedCount : 0, shieldsOn: false)
        PrintScaffold(step: 8, tag: "Make it yours", title: has ? words.title : "Which apps\nto block?", grain: true,
                      primaryTitle: primaryTitle(has), primaryAction: { primary(has) },
                      secondaryTitle: has ? "Change apps" : "Skip for now",
                      secondaryAction: { has ? (picking = true) : next() }) {
            VStack(alignment: .leading, spacing: 18) {
                Text(has ? "They lock when you start a session." : "They only lock during a session.")
                    .font(PrintFont.mono(14))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("You can change your selection anytime.")
                    .font(PrintFont.mono(12))
                    .foregroundStyle(Ink.ink.opacity(0.65))
                tiles(has)
                if has {
                    Stamp(text: words.stamp(lockedCount), color: Ink.blue, size: 22, tilt: -5)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .familyActivityPicker(
            isPresented: $picking,
            selection: Binding(get: { restrictions.selection }, set: { restrictions.setSelection($0) })
        )
    }

    private func primaryTitle(_ has: Bool) -> String {
        if has { return "LOOKS RIGHT" }
        switch restrictions.status {
        case .denied: return "OPEN SETTINGS"
        case .needsAuthorization, .failed: return "CONTINUE"
        default: return "CHOOSE APPS"
        }
    }

    private func primary(_ has: Bool) {
        if has { next(); return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-onboarding") { next(); return }
        #endif
        switch restrictions.status {
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        case .needsAuthorization, .failed:
            Task { await restrictions.requestAuthorization() }
        default:
            picking = true
        }
    }

    /// One plain colored tile per picked app (not the apps' real icons), with a small lock on each
    /// corner. Before anything is picked, a grid of empty dashed slots.
    @ViewBuilder
    private func tiles(_ has: Bool) -> some View {
        let apps = Array(restrictions.selection.applicationTokens)
        let cats = Array(restrictions.selection.categoryTokens)
        if has {
            let columns = [GridItem(.adaptive(minimum: 44, maximum: 56), spacing: 18)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                // Plain locked tiles, one per pick, not the apps' own icons.
                ForEach(0..<min(apps.count + cats.count, 15), id: \.self) { i in
                    lockedIcon {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill([Ink.blue, Ink.red, Ink.sun, Ink.ink][i % 4])
                            .scaleEffect(1 / 2.8)
                    }
                }
                if lockedCount > 15 {
                    Text("+\(lockedCount - 15)")
                        .font(PrintFont.bold(16))
                        .foregroundStyle(Ink.paper)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Ink.ink))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(lockedCount) apps chosen")
        } else {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Ink.ink.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Image(systemName: "plus").foregroundStyle(Ink.ink.opacity(0.5)))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("No apps chosen yet")
        }
    }

    private func lockedIcon<Icon: View>(@ViewBuilder icon: () -> Icon) -> some View {
        icon()
            .scaleEffect(2.8)
            .frame(width: 30, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(Circle().fill(Ink.ink))
                    .overlay(Circle().stroke(Ink.paper, lineWidth: 1.5))
                    .offset(x: 5, y: 5)
            }
            .frame(width: 44, height: 44)
    }
}

// MARK: 8. Your year

/// Bad news, then good news: a year of days, the phone's share crossed out in orange, then half of
/// it turned blue. Plain arithmetic from the hours answer, labeled as an estimate.
struct YearStep: View {
    let hoursIndex: Int
    let next: () -> Void
    @State private var shown = 0
    @State private var reveal = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var days: Int { OnboardingMath.daysPerYear(hoursIndex: hoursIndex) }
    /// Full days a 25-minute daily session adds up to in a 365-day year (6 at 25 minutes).
    private var focusDays: Int { OnboardingMath.focusDaysPerYear(minutesPerDay: 25) }

    var body: some View {
        PrintScaffold(step: 7, tag: "What it adds up to", title: "Your next\nyear.", grain: true,
                      primaryTitle: "LET\u{2019}S DO IT", primaryAction: next) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(shown) DAYS")
                    .font(PrintFont.head(92))
                    .misprint(Ink.sun)
                    .foregroundStyle(Ink.orange)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("\(days) days")
                Text("That\u{2019}s how much time your current daily average would add up to over a year.")
                    .font(PrintFont.mono(15))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Canvas { ctx, size in
                    let cols = 26, rows = 14, gap: CGFloat = 2
                    let cell = (size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
                    for i in 0..<(cols * rows) {
                        let rect = CGRect(x: CGFloat(i % cols) * (cell + gap), y: CGFloat(i / cols) * (cell + gap),
                                          width: cell, height: cell)
                        let color: Color = reveal && i < focusDays ? Ink.sun : (i < shown ? Ink.orange : Ink.ink.opacity(0.1))
                        ctx.fill(Path(rect), with: .color(color))
                    }
                }
                .aspectRatio(26.0 / 14.0, contentMode: .fit)
                .padding(14)
                .background(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 8)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("But here\u{2019}s another number.")
                        .font(PrintFont.mono(15))
                        .foregroundStyle(Ink.ink)
                    HStack(spacing: 14) {
                        Text("+\(focusDays)")
                            .font(PrintFont.head(40))
                            .foregroundStyle(Ink.ink)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Ellipse().fill(Ink.sun))
                            .rotationEffect(.degrees(-4))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("25 MINUTES A DAY.")
                                .font(PrintFont.head(30))
                                .foregroundStyle(Ink.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("That\u{2019}s more than \(OnboardingMath.spelled(focusDays)) full days of focused time over a year.")
                                .font(PrintFont.bold(17))
                                .foregroundStyle(Ink.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 10)
                .opacity(reveal ? 1 : 0)
                .accessibilityElement(children: .combine)
                Text("An estimate from your answer, in full 24-hour days.")
                    .font(PrintFont.mono(11, .regular))
                    .foregroundStyle(Ink.soft)
            }
        }
        .task {
            if effectiveReduceMotion(systemReduceMotion) { shown = days; reveal = true; return }
            for k in 1...30 {
                let t = Double(k) / 30
                shown = Int(Double(days) * (1 - pow(1 - t, 3)))
                guard await printPause(0.04) else { return }
            }
            shown = days
            guard await printPause(0.7) else { return }
            withAnimation(.easeOut(duration: 0.5)) { reveal = true }
        }
    }
}

// MARK: 9. Goals

/// A to-do list on notebook paper, in handwriting.
struct GoalsStep: View {
    @Binding var goals: Set<String>
    let next: () -> Void

    private static let items: [(key: String, text: String)] = [
        ("Study", "Studying"), ("Train", "Working out"), ("Create", "Creating something"),
        ("Sleep", "Getting more rest"), ("Read", "Reading"), ("People", "Spending time with people")
    ]

    var body: some View {
        PrintScaffold(step: 9, tag: "Make it yours", background: Ink.notebook, title: "What do you\nwant more of?",
                      primaryTitle: "NEXT", primaryEnabled: !goals.isEmpty, primaryAction: next,
                      secondaryTitle: "Skip", secondaryAction: next) {
            Text("Your plan makes room for these.")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Self.items, id: \.key) { item in
                    let on = goals.contains(item.key)
                    Button {
                        if on { goals.remove(item.key) } else { goals.insert(item.key) }
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Ink.ink, lineWidth: 3)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if on {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 26, weight: .black))
                                            .foregroundStyle(Ink.blue)
                                            .offset(x: 3, y: -6)
                                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                                    }
                                }
                            Text(item.text)
                                .font(PrintFont.hand(30))
                                .foregroundStyle(Ink.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 34)
                        .frame(height: 49)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: on)
                    .sensoryFeedback(.selection, trigger: on)
                    .accessibilityLabel(item.text)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .background(alignment: .bottom) {
                        Rectangle().fill(Ink.blue.opacity(0.2)).frame(height: 2)
                    }
                }
            }
            .background(alignment: .leading) {
                Rectangle().fill(Ink.orange.opacity(0.4)).frame(width: 2).padding(.leading, 18)
            }
        }
    }
}

// MARK: 12. Your lock-in plan

/// A printed receipt of the user's own plan, made from their answers (mock:
/// docs/design/schedule-v2.html, screen 1). What pulls them in is struck through and swapped for
/// what the time is for; the time sits on a tear-off stub with "Can't do 4:00?", which opens the
/// schedule screens (`WhenSteps.swift`). They take it, or make it easier first. The plan is saved
/// and then shown every day on the Focus screen.
struct PlanStep: View {
    let hoursIndex: Int?
    /// The real number was shown (and the app cannot read it), so the guess is not printed.
    var realShown = false
    let categories: Set<String>
    let goals: Set<String>
    /// "Make it easier" steps, kept by the flow so they survive a trip to the schedule screens.
    @Binding var easier: Int
    /// The time picked on the schedule screens, if any.
    var timeChoice: TimeChoice? = nil
    /// "Can't do 4:00?": opens the schedule screens with the plan as it is now.
    var cantDo: ((LockInPlan) -> Void)? = nil
    let next: () -> Void
    @State private var lines = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var plan: LockInPlan {
        var p = PlanRules.make(hoursIndex: hoursIndex, pulls: categories, goals: goals)
        for _ in 0..<easier { p = PlanRules.apply(.easier, to: p) }
        if let timeChoice {
            p.startMinute = timeChoice.startMinute
            p.weekdays = timeChoice.weekdays
            p.dayStarts = timeChoice.dayStarts
        }
        return p
    }

    /// "VIDEO + SOCIAL" -> "STUDYING", when both are known.
    private var swap: (from: String, to: String)? {
        let p = plan
        guard !p.pulls.isEmpty, let task = p.task else { return nil }
        return (p.pulls.prefix(2).joined(separator: " + ").uppercased(), task.uppercased())
    }

    private var rows: [(label: String, value: String)] {
        let p = plan
        var out: [(label: String, value: String)] = []
        if let hoursIndex, !realShown { out.append(("PHONE NOW", "\(hoursTabs[min(max(hoursIndex, 0), 3)]) A DAY")) }
        if swap == nil {
            if !p.pulls.isEmpty { out.append(("PULLS YOU IN", p.pulls.prefix(2).joined(separator: " + ").uppercased())) }
            if let task = p.task { out.append(("FOR", task.uppercased())) }
        }
        out.append(("LOCK-INS", "\(p.sessionsPerDay) \u{00D7} \(p.minutes) MIN"))
        return out
    }

    private var wonBack: String {
        let m = plan.minutesPerDay
        if m < 60 { return "\(m) MIN" }
        return m % 60 == 0 ? "\(m / 60)H" : "\(m / 60)H \(m % 60)M"
    }

    private var daysText: String {
        let d = plan.weekdays
        if d == [2, 3, 4, 5, 6] { return "WEEKDAYS AT" }
        if d.count == 7 { return "EVERY DAY AT" }
        let names = [2: "MON", 3: "TUE", 4: "WED", 5: "THU", 6: "FRI", 7: "SAT", 1: "SUN"]
        return d.sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }.compactMap { names[$0] }.joined(separator: " ") + " AT"
    }

    /// The stub's time: one time, or "fitted" when it changes per day.
    private var timeText: String {
        let p = plan
        let starts = Set(p.weekdays.map { p.startMinute(weekday: $0) })
        return starts.count > 1 ? "EACH DAY, FITTED" : DailyNudge.timeText(minute: p.startMinute).uppercased()
    }

    private var easeAction: (() -> Void)? {
        guard PlanRules.rung(plan) > 0 else { return nil }
        return { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { easier += 1 } }
    }

    var body: some View {
        PrintScaffold(step: 10, tag: "Your plan", title: "Your lock-in\nplan.", grain: true,
                      primaryTitle: "THIS IS MY PLAN", primaryAction: accept,
                      secondaryTitle: easeAction == nil ? nil : "Make it easier", secondaryAction: easeAction) {
            Text("When and how long you\u{2019}ll lock in. Change it anytime.")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
            VStack(spacing: 0) {
                receipt
                stub
            }
            .padding(.top, 4)
        }
        .task {
            let count = rows.count + (swap == nil ? 0 : 1)
            if effectiveReduceMotion(systemReduceMotion) { lines = count; return }
            for i in 1...count {
                guard await printPause(0.3) else { return }
                withAnimation(.easeOut(duration: 0.2)) { lines = i }
            }
        }
    }

    private var receipt: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.black).frame(height: 16)
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            VStack(alignment: .leading, spacing: 10) {
                Text("PLAN FOR: YOU")
                    .font(PrintFont.mono(15, .heavy)).tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                if let swap {
                    SwapRow(from: swap.from, to: swap.to)
                        .opacity(lines > 0 ? 1 : 0)
                }
                let offset = swap == nil ? 0 : 1
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                        Spacer(minLength: 12)
                        Text(row.value).fontWeight(.heavy).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .font(PrintFont.mono(15))
                    .opacity(i + offset < lines ? 1 : 0)
                }
                dashes
                HStack(alignment: .firstTextBaseline) {
                    Text("YOU WIN BACK").font(PrintFont.mono(15))
                    Spacer(minLength: 8)
                    Text("\(wonBack) / DAY")
                        .font(PrintFont.head(36))
                        .foregroundStyle(Ink.blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                }
                HStack {
                    Text("THIS YEAR")
                    Spacer()
                    Text("\u{2248} \(PlanRules.daysPerYear(plan)) DAYS").fontWeight(.heavy)
                }
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.soft)
            }
            .foregroundStyle(Ink.ink)
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReceiptEdge().fill(Color.white).shadow(color: .black.opacity(0.16), radius: 12, y: 10))
            .padding(.horizontal, 10)
            .offset(y: -8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// The tear-off stub: the time, and "Can't do 4:00?".
    private var stub: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(daysText)
                    .font(PrintFont.mono(10, .bold)).tracking(1.4)
                    .foregroundStyle(Ink.soft)
                Text(timeText)
                    .font(PrintFont.head(timeText.count > 9 ? 22 : 30))
                    .foregroundStyle(Ink.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            if let cantDo {
                Button { cantDo(plan) } label: {
                    Text(timeChoice == nil ? "Can\u{2019}t do \(DailyNudge.timeText(minute: plan.startMinute))?" : "Change time")
                        .font(PrintFont.body(13, .heavy))
                        .foregroundStyle(Ink.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 40)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2))
                        .background(Capsule().fill(Ink.ink).offset(y: 3))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan-cant-do")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(hex: 0xF4F4F0))
        .overlay(alignment: .top) {
            DashLine()
                .stroke(Ink.ink.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                .frame(height: 2)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 6)
        .rotationEffect(.degrees(1.2), anchor: .topLeading)
        .padding(.horizontal, 10)
        .offset(y: -8)
    }

    private var dashes: some View {
        Text(String(repeating: "- ", count: 30))
            .font(PrintFont.mono(13))
            .foregroundStyle(Ink.ink.opacity(0.3))
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityHidden(true)
    }

    private var accessibilitySummary: String {
        let p = plan
        var s = "Your lock-in plan:"
        if let swap { s += " \(swap.from.lowercased()) swapped for \(swap.to.lowercased())." }
        s += " \(p.sessionsPerDay) lock-ins of \(p.minutes) minutes, \(daysText.lowercased()) \(timeText.lowercased())."
        s += " You win back \(p.minutesPerDay) minutes a day, about \(PlanRules.daysPerYear(p)) days this year."
        return s
    }

    private func accept() {
        PlanStore.save(plan)
        next()
    }
}

/// "VIDEO + SOCIAL" with a red pen strike, an arrow, and a blue "STUDYING" sticker.
private struct SwapRow: View {
    let from: String
    let to: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(from)
                .font(PrintFont.mono(15, .bold))
                .foregroundStyle(Ink.ink.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .overlay {
                    GeometryReader { g in
                        Path { p in
                            p.move(to: CGPoint(x: -3, y: g.size.height * 0.58))
                            p.addCurve(to: CGPoint(x: g.size.width + 3, y: g.size.height * 0.45),
                                       control1: CGPoint(x: g.size.width * 0.3, y: g.size.height * 0.4),
                                       control2: CGPoint(x: g.size.width * 0.6, y: g.size.height * 0.62))
                        }
                        .stroke(Ink.red, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    }
                }
            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Ink.ink)
            Text(to)
                .font(PrintFont.head(22))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 9).fill(Ink.blue))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Ink.ink, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 9).fill(Ink.ink).offset(y: 3))
                .rotationEffect(.degrees(-3))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: 11. Promise

/// A contract. Hold the button for 2 seconds to sign it. VoiceOver gets a plain "Sign" action.
struct PromiseStep: View {
    @Binding var signed: Bool
    /// The goals picked on slide 9; the first one names what the 25 minutes are for.
    var goals: Set<String> = []
    let next: () -> Void
    @State private var ink: CGFloat = 0
    @State private var holding = false
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let holdSeconds = 2.0

    /// In slide 9's order, so the choice does not depend on set order.
    private static let activities: [(key: String, phrase: String)] = [
        ("Study", "my studies"), ("Train", "my workout"), ("Create", "my project"),
        ("Sleep", "my rest"), ("Read", "my reading"), ("People", "the people around me")
    ]

    private var activity: String {
        Self.activities.first { goals.contains($0.key) }?.phrase ?? "one thing"
    }

    var body: some View {
        PrintScaffold(step: 10, tag: "Your promise", title: "One small\ncommitment.", grain: true,
                      primaryView: AnyView(holdButton),
                      secondaryTitle: "Not now", secondaryAction: { signed = false; next() }) {
            VStack(alignment: .leading, spacing: 12) {
                Text("AGREEMENT").font(PrintFont.mono(12)).tracking(2).foregroundStyle(Ink.ink.opacity(0.6))
                (Text("I\u{2019}ll give \(activity) my attention for ")
                 + Text("25 minutes").bold().foregroundColor(Ink.ink)
                 + Text("."))
                    .font(PrintFont.bold(24))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("If I get distracted, I\u{2019}ll come back to it.")
                    .font(PrintFont.bold(20))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No need to be perfect.")
                    .font(PrintFont.mono(12))
                    .foregroundStyle(Ink.ink.opacity(0.6))
                ZStack(alignment: .bottomLeading) {
                    Signature()
                        .trim(from: 0, to: ink)
                        .stroke(Ink.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 190, height: 56)
                        .padding(.leading, 6).padding(.bottom, 6)
                    Rectangle().fill(Ink.ink).frame(height: 3)
                }
                .frame(height: 76)
                .padding(.top, 20)
                .accessibilityHidden(true)
                Text("SIGNED, " + Date().formatted(.dateTime.day().month(.abbreviated)).uppercased())
                    .font(PrintFont.mono(12))
                    .foregroundStyle(Ink.ink.opacity(0.6))
            }
            .padding(22)
            .background(Color.white)
            .shadow(color: .black.opacity(0.2), radius: 12, y: 10)
        }
    }

    private var holdButton: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Ink.ink)
            GeometryReader { g in
                Rectangle().fill(Ink.orange).frame(width: g.size.width * ink)
            }
            Text(done ? "INTENTION SET" : holding ? "KEEP HOLDING" : "HOLD TO SET MY INTENTION")
                .font(PrintFont.bold(19)).tracking(2)
                .foregroundStyle(Ink.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 60)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: Self.holdSeconds, maximumDistance: 60) {
            commit()
        } onPressingChanged: { pressing in
            guard !done else { return }
            holding = pressing
            if pressing { withAnimation(.linear(duration: Self.holdSeconds)) { ink = 1 } }
            else { withAnimation(.easeOut(duration: 0.3)) { ink = 0 } }
        }
        .sensoryFeedback(.success, trigger: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold to set your intention")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Sign") { commit() }
        .accessibilityIdentifier("hold-to-sign")
    }

    private func commit() {
        guard !done else { return }
        done = true
        holding = false
        ink = 1
        signed = true
        Task {
            _ = await printPause(effectiveReduceMotion(systemReduceMotion) ? 0.2 : 0.8)
            next()
        }
    }
}

/// A loose hand-written scribble, drawn as the user holds.
private struct Signature: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.7))
        p.addCurve(to: CGPoint(x: w * 0.18, y: h * 0.1), control1: CGPoint(x: w * 0.05, y: h * 0.2), control2: CGPoint(x: w * 0.12, y: 0))
        p.addCurve(to: CGPoint(x: w * 0.22, y: h * 0.85), control1: CGPoint(x: w * 0.26, y: h * 0.3), control2: CGPoint(x: w * 0.1, y: h * 0.9))
        p.addCurve(to: CGPoint(x: w * 0.45, y: h * 0.45), control1: CGPoint(x: w * 0.32, y: h * 0.8), control2: CGPoint(x: w * 0.36, y: h * 0.4))
        p.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.75), control1: CGPoint(x: w * 0.52, y: h * 0.5), control2: CGPoint(x: w * 0.48, y: h * 0.85))
        p.addCurve(to: CGPoint(x: w * 0.72, y: h * 0.35), control1: CGPoint(x: w * 0.62, y: h * 0.65), control2: CGPoint(x: w * 0.64, y: h * 0.3))
        p.addCurve(to: CGPoint(x: w, y: h * 0.55), control1: CGPoint(x: w * 0.8, y: h * 0.4), control2: CGPoint(x: w * 0.9, y: h * 0.7))
        return p
    }
}
