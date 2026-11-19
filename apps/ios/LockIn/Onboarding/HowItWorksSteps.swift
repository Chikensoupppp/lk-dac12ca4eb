import SwiftUI

// Three "how it works" slides between the goals and the plan (mock: docs/design/how-it-works-v2.html).
// They share one moving background, a riso halftone field, and each slide is something the user does:
// slide the real lock slider, swipe notifications away to "Later", watch the week stack up.
// One short line each. No help paragraphs.

// MARK: Moving halftone background

/// A wave that spreads out through the dots from one point, then fades.
struct FieldRipple: Identifiable {
    let id = UUID()
    /// Where it starts, as a fraction of the screen.
    let origin: UnitPoint
    let start: Date
    var amp: Double = 0.9
    var speed: Double = 520
}

/// Two inks a little off-register, like a real riso print: blue dots everywhere the wave is,
/// sunflower dots only on its crest. The wave drifts slowly up and across (no back-and-forth pulse)
/// and stays low on the page so the headline is always clean. Still when motion is limited.
struct HalftoneField: View {
    /// Where the dots begin, as a fraction of the height. They fade in over the next 35%.
    var fadeStart: CGFloat = 0.55
    var ripples: [FieldRipple] = []
    @State private var born = Date()
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        let still = motionLimited(systemReduceMotion)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { context in
            let t = still ? 2.0 : context.date.timeIntervalSince(born)
            let live = still ? [] : ripples
            Canvas { ctx, size in
                Self.draw(in: &ctx, size: size, t: t, now: context.date, fadeStart: Double(fadeStart), ripples: live)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct LiveRipple {
        let x: Double, y: Double, dt: Double, amp: Double, speed: Double
    }

    private static func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double, now: Date,
                             fadeStart: Double, ripples: [FieldRipple]) {
        let width = Double(size.width), height = Double(size.height)
        let top = height * fadeStart, fade = height * 0.35
        let live = ripples.compactMap { r -> LiveRipple? in
            let dt = now.timeIntervalSince(r.start)
            guard dt >= 0, dt < 4 else { return nil }
            return LiveRipple(x: Double(r.origin.x) * width, y: Double(r.origin.y) * height, dt: dt, amp: r.amp, speed: r.speed)
        }
        let step = 15.0
        var blue = Path(), sun = Path()
        var row = 0
        var y = step / 2
        while y < height + step {
            var x = row.isMultiple(of: 2) ? 0 : step / 2
            while x < width + step {
                let v = value(x: x, y: y, t: t, top: top, fade: fade, ripples: live)
                if v > 0.05 {
                    let rb = 5.4 * min(v, 1)
                    if rb > 0.4 { blue.addEllipse(in: CGRect(x: x - rb, y: y - rb, width: rb * 2, height: rb * 2)) }
                    let rs = 5.6 * min(max((v - 0.62) / 0.5, 0), 1)
                    if rs > 0.4 { sun.addEllipse(in: CGRect(x: x + 2.2 - rs, y: y + 1.6 - rs, width: rs * 2, height: rs * 2)) }
                }
                x += step
            }
            y += step
            row += 1
        }
        // Tone-on-tone: darker and lighter cream dots on the paper, so the objects carry the color.
        ctx.fill(sun, with: .color(Color(hex: 0xC9CAC1).opacity(0.9)))
        ctx.fill(blue, with: .color(Color(hex: 0xB9BAB0).opacity(0.55)))
    }

    private static func value(x: Double, y: Double, t: Double, top: Double, fade: Double, ripples: [LiveRipple]) -> Double {
        let m = min(max((y - top) / fade, 0), 1)
        if m <= 0 { return 0 }
        let a = sin(x * 0.014 - y * 0.010 + t * 0.62 + 1.4 * sin(y * 0.006 + t * 0.18))
        let b = sin(y * 0.012 + x * 0.006 + t * 0.47)
        var v = m * (0.50 + 0.30 * a + 0.20 * b)
        let reach = min(m * 1.8, 1)
        for r in ripples {
            let d = hypot(x - r.x, y - r.y)
            let k = (d - r.dt * r.speed) / 52
            v += r.amp * exp(-k * k) * exp(-r.dt) * reach
        }
        return v
    }
}

/// The caption under the headline. The old line leaves first, then the new one arrives,
/// so the two never overlap.
private struct SwapCaption: View {
    let first: String
    let second: String
    let swapped: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(first)
                .opacity(swapped ? 0 : 1)
                .offset(y: swapped ? -6 : 0)
                .animation(.easeOut(duration: 0.18), value: swapped)
            Text(second)
                .opacity(swapped ? 1 : 0)
                .offset(y: swapped ? 0 : 6)
                .animation(.easeOut(duration: 0.3).delay(0.16), value: swapped)
        }
        .font(PrintFont.mono(14))
        .foregroundStyle(Ink.ink)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(swapped ? second : first)
    }
}

private var compactScreen: Bool { UIScreen.main.bounds.height < 700 }

// MARK: One slide. You're in.

/// The real "slide to lock in" control, with the brain as the knob. It follows the finger 1:1,
/// and a flick counts too. A tap also locks it (VoiceOver, UI tests). NEXT unlocks once it is slid.
struct SlideToLockStep: View {
    let next: () -> Void
    @State private var x: CGFloat = 0
    @State private var locked = false
    @State private var pop = false
    @State private var ripples: [FieldRipple] = []
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    private let height: CGFloat = 76
    private let knob: CGFloat = 64

    var body: some View {
        PrintScaffold(step: 10, title: "One slide.\nYou\u{2019}re in.",
                      primaryTitle: "NEXT", primaryEnabled: locked || voiceOver, primaryAction: next,
                      backdrop: AnyView(HalftoneField(fadeStart: 0.55, ripples: ripples))) {
            SwapCaption(first: "Go on. Try it.", second: "That\u{2019}s how every session starts.", swapped: locked)
            track
                .padding(.top, compactScreen ? 60 : 150)
        }
        .sensoryFeedback(.success, trigger: locked)
    }

    private var track: some View {
        GeometryReader { proxy in
            let maxX = max(proxy.size.width - height, 1)
            let progress = Double(min(x / maxX, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.ink)
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0x2B4C97), Ink.blue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: height + x)
                    .opacity(x > 0 ? 1 : 0)
                ShimmerLabel(text: "SLIDE TO LOCK IN")
                    .frame(maxWidth: .infinity)
                    .padding(.leading, height - 8)
                    .opacity(1 - min(progress * 2, 1))
                Text("LOCKED IN")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, height - 8)
                    .opacity(locked ? 1 : 0)
                    .accessibilityHidden(true)
                knobView
                    .offset(x: x)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                guard !locked else { return }
                                x = min(max(value.translation.width, 0), maxX)
                            }
                            .onEnded { value in
                                guard !locked else { return }
                                // Commit on where the flick was going, not only where the finger let go.
                                if x > maxX * 0.7 || value.predictedEndTranslation.width > maxX { lock(maxX) }
                                else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { x = 0 } }
                            }
                    )
                    .onTapGesture { lock(maxX) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(locked ? "Locked in" : "Slide to lock in")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("onboarding-slide-knob")
                    .accessibilityAction { lock(maxX) }
            }
        }
        .frame(height: height)
        .compositingGroup()
        .shadow(color: Ink.ink.opacity(0.22), radius: 15, y: 14)
    }

    private var knobView: some View {
        Circle()
            .fill(RadialGradient(colors: [.white, Color(hex: 0xECEDE8)], center: UnitPoint(x: 0.35, y: 0.3),
                                 startRadius: 0, endRadius: knob * 0.7))
            .frame(width: knob, height: knob)
            .overlay(Image("BrainExact").resizable().scaledToFit().frame(width: knob + 6).offset(y: 1))
            .overlay(alignment: .bottomTrailing) {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Ink.ink))
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 3, y: 3)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 7, y: 6)
            .scaleEffect(pop ? 1.08 : 1)
            .padding((height - knob) / 2)
    }

    private func lock(_ maxX: CGFloat) {
        guard !locked else { return }
        if effectiveReduceMotion(systemReduceMotion) {
            x = maxX
            locked = true
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            x = maxX
            locked = true
        }
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.84, y: 0.62), start: .now, amp: 1.2))
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { pop = true }
        Task {
            guard await printPause(0.16) else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { pop = false }
        }
    }
}

/// "SLIDE TO LOCK IN" with a soft light sweeping across it, left to right.
private struct ShimmerLabel: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        let still = motionLimited(systemReduceMotion)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { context in
            let phase = (context.date.timeIntervalSinceReferenceDate * 0.55).truncatingRemainder(dividingBy: 1.4) - 0.2
            label(Ink.paper.opacity(still ? 0.75 : 0.4))
                .overlay {
                    if !still {
                        label(.white)
                            .mask {
                                LinearGradient(stops: [.init(color: .clear, location: 0),
                                                       .init(color: .white, location: 0.5),
                                                       .init(color: .clear, location: 1)],
                                               startPoint: UnitPoint(x: phase - 0.18, y: 0.5),
                                               endPoint: UnitPoint(x: phase + 0.18, y: 0.5))
                            }
                    }
                }
        }
        .accessibilityHidden(true)
    }

    private func label(_ color: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .tracking(3)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: Swipe later.

/// Three notifications drop in. The user swipes them away (or they go by themselves after a moment),
/// and a dark "Later" card rises in their place.
struct LaterStep: View {
    let next: () -> Void
    @State private var shown = 0
    @State private var gone: Set<Int> = []
    @State private var drag: [Int: CGFloat] = [:]
    @State private var laterShown = false
    @State private var fanned = false
    @State private var ripples: [FieldRipple] = []
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    /// The round mark on a notification: a person's initial or a plain symbol, never an app icon.
    private struct Note {
        let initial: String?
        let symbol: String
        let tile: Color
        let glyph: Color
        let app: String
        let text: String
    }

    private static let notes = [
        Note(initial: "M", symbol: "", tile: Ink.blue, glyph: .white, app: "Social", text: "Mia and 11 others liked your post"),
        Note(initial: nil, symbol: "timer", tile: Ink.sun, glyph: Ink.ink, app: "Video", text: "Up next in 5\u{2026} 4\u{2026} 3\u{2026}"),
        Note(initial: nil, symbol: "gift.fill", tile: Ink.ink, glyph: .white, app: "Games", text: "Your free spin is ready"),
    ]

    var body: some View {
        PrintScaffold(step: 11, title: "Swipe\nlater.", primaryTitle: "NEXT", primaryAction: next,
                      backdrop: AnyView(HalftoneField(fadeStart: 0.55, ripples: ripples))) {
            SwapCaption(first: "Your apps wait till you\u{2019}re done.", second: "Nothing lost. Just later.", swapped: laterShown)
            ZStack {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in noteRow(i) }
                }
                laterCard
            }
            .padding(.top, compactScreen ? 20 : 48)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: gone.count)
        .sensoryFeedback(.success, trigger: laterShown)
        .task { await run() }
    }

    private func noteRow(_ i: Int) -> some View {
        let note = Self.notes[i]
        let isIn = i < shown
        let isGone = gone.contains(i)
        let dx: CGFloat = isGone ? 460 : (drag[i] ?? 0)
        return HStack(spacing: 12) {
            Group {
                if let initial = note.initial {
                    Text(initial).font(.system(size: 19, weight: .bold, design: .rounded))
                } else {
                    Image(systemName: note.symbol).font(.system(size: 18, weight: .semibold))
                }
            }
            .foregroundStyle(note.glyph)
            .frame(width: 42, height: 42)
            .background(Circle().fill(note.tile))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(note.app)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Ink.ink)
                    Spacer()
                    Text("now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Ink.soft)
                }
                Text(note.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Ink.ink.opacity(0.82))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 74)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.55)))
        }
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.9), lineWidth: 0.5))
        .shadow(color: Ink.ink.opacity(0.13), radius: 14, y: 10)
        .rotationEffect(.degrees(Double(dx / 460) * 7))
        .offset(x: dx, y: isIn ? 0 : -60)
        .scaleEffect(isIn ? 1 : 0.94)
        .opacity(isIn && !isGone ? 1 : 0)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    guard isIn, !isGone else { return }
                    let w = value.translation.width
                    // Right follows the finger; left gives a little and then resists.
                    drag[i] = w >= 0 ? w : -(-w * 40) / (40 + -w)
                }
                .onEnded { value in
                    guard isIn, !isGone else { return }
                    if value.translation.width > 90 || value.predictedEndTranslation.width > 220 { fling(i) }
                    else { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { drag[i] = 0 } }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.app): \(note.text)")
        .accessibilityAction(named: "Swipe to later") { fling(i) }
        .accessibilityHidden(!isIn || isGone)
    }

    private var laterCard: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Ink.ink.opacity(0.55))
                .frame(height: 92)
                .padding(.horizontal, 26)
                .offset(y: fanned ? 20 : 0)
                .opacity(0.3)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Ink.ink.opacity(0.55))
                .frame(height: 92)
                .padding(.horizontal, 12)
                .offset(y: fanned ? 10 : 0)
                .opacity(0.55)
            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.blue))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Later")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Ink.paper)
                    Text("3 waiting till you\u{2019}re done")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Ink.paper.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 6)
                Text("25:00")
                    .font(PrintFont.mono(13))
                    .foregroundStyle(Ink.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Ink.sun))
            }
            .padding(.horizontal, 18)
            .frame(height: 92)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Ink.ink))
            .shadow(color: Ink.ink.opacity(0.28), radius: 18, y: 18)
        }
        .opacity(laterShown ? 1 : 0)
        .offset(y: laterShown ? 0 : 50)
        .scaleEffect(laterShown ? 1 : 0.92)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Later: 3 waiting till you're done")
        .accessibilityHidden(!laterShown)
    }

    private func fling(_ i: Int) {
        guard !gone.contains(i) else { return }
        if effectiveReduceMotion(systemReduceMotion) {
            gone.insert(i)
        } else {
            withAnimation(.easeIn(duration: 0.38)) { _ = gone.insert(i) }
            ripples.append(FieldRipple(origin: UnitPoint(x: 1, y: 0.45 + 0.1 * Double(i)),
                                       start: Date.now.addingTimeInterval(0.25), amp: 0.7, speed: 480))
        }
        if gone.count == Self.notes.count { showLater() }
    }

    private func showLater() {
        if effectiveReduceMotion(systemReduceMotion) {
            laterShown = true
            fanned = true
            return
        }
        Task {
            guard await printPause(0.35) else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.74)) { laterShown = true }
            guard await printPause(0.25) else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { fanned = true }
        }
    }

    private func run() async {
        if effectiveReduceMotion(systemReduceMotion) {
            shown = Self.notes.count
        } else {
            guard await printPause(0.45) else { return }
            for k in 1...Self.notes.count {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { shown = k }
                guard await printPause(0.22) else { return }
            }
        }
        // A moment for the user to swipe them away; then the rest go by themselves.
        guard await printPause(2.2) else { return }
        for i in 0..<Self.notes.count where !gone.contains(i) {
            fling(i)
            guard await printPause(0.3) else { return }
        }
    }
}

// MARK: Stack up the days.

/// Monday to Sunday drop in and stack with a little squash, Sunday in sunflower,
/// and the brain lands on top. Tap the brain and it hops.
struct StackDaysStep: View {
    let next: () -> Void
    @State private var dropped = 0
    @State private var squash: Int?
    @State private var brainIn = false
    @State private var hop = false
    @State private var bob = false
    @State private var ripples: [FieldRipple] = []
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private static let widths: [CGFloat] = [228, 214, 222, 208, 218, 204, 192]
    private static let tilts: [Double] = [-1, 0.8, -0.6, 1.1, -0.9, 0.5, -1.4]
    private static let shifts: [CGFloat] = [0, 6, -5, 8, -3, 4, -6]

    var body: some View {
        PrintScaffold(step: 12, title: "Stack up\nthe days.", primaryTitle: "NEXT", primaryAction: next,
                      backdrop: AnyView(HalftoneField(fadeStart: 0.6, ripples: ripples))) {
            Text("One session a day. Watch it grow.")
                .font(PrintFont.mono(14))
                .foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: compactScreen ? 4 : 6) {
                brain
                ForEach((0..<7).reversed(), id: \.self) { i in block(i) }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, compactScreen ? 4 : 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Seven days stacked, Monday to Sunday, with the brain on top")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: dropped)
        .sensoryFeedback(.impact(weight: .heavy), trigger: brainIn)
        .task { await run() }
    }

    private var brain: some View {
        Image("BrainExact")
            .resizable()
            .scaledToFit()
            .frame(width: compactScreen ? 70 : 86)
            .rotationEffect(.degrees(brainIn ? -4 : -18))
            .offset(y: brainIn ? (bob ? -3 : 3) : -260)
            .scaleEffect(hop ? 1.12 : 1)
            .opacity(brainIn ? 1 : 0)
            .onTapGesture(perform: hopOnce)
    }

    private func block(_ i: Int) -> some View {
        let isSun = i == 6
        let isIn = i < dropped
        let fill: Color = isSun ? Ink.sun : (i.isMultiple(of: 2) ? Ink.blue : Color(hex: 0x3A5EAD))
        return HStack {
            Text(Self.days[i])
                .font(PrintFont.mono(13))
                .tracking(1)
            Spacer()
            Image(systemName: isSun ? "star.fill" : "checkmark")
                .font(.system(size: 12, weight: .heavy))
        }
        .foregroundStyle(isSun ? Ink.ink : Ink.receipt)
        .padding(.horizontal, 16)
        .frame(width: Self.widths[i], height: compactScreen ? 34 : 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
        .shadow(color: Ink.ink.opacity(0.16), radius: 7, y: 6)
        .scaleEffect(x: squash == i ? 1.07 : 1, y: squash == i ? 0.88 : 1, anchor: .bottom)
        .rotationEffect(.degrees(Self.tilts[i]))
        .offset(x: Self.shifts[i], y: isIn ? 0 : -330)
        .opacity(isIn ? 1 : 0)
    }

    private func hopOnce() {
        guard brainIn, !effectiveReduceMotion(systemReduceMotion) else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { hop = true }
        Task {
            guard await printPause(0.15) else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { hop = false }
        }
    }

    private func run() async {
        if effectiveReduceMotion(systemReduceMotion) {
            dropped = Self.days.count
            brainIn = true
            return
        }
        guard await printPause(0.5) else { return }
        for i in 0..<Self.days.count {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { dropped = i + 1 }
            guard await printPause(0.2) else { return }
            withAnimation(.spring(response: 0.16, dampingFraction: 0.6)) { squash = i }
            ripples.append(FieldRipple(origin: UnitPoint(x: 0.5, y: 0.86 - 0.054 * Double(i)), start: .now, amp: 0.45, speed: 420))
            guard await printPause(0.1) else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { squash = nil }
            guard await printPause(0.04) else { return }
        }
        guard await printPause(0.15) else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { brainIn = true }
        guard await printPause(0.16) else { return }
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.5, y: 0.45), start: .now, amp: 0.9))
        guard await printPause(0.7) else { return }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = true }
    }
}
